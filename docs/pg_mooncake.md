# pg_mooncake: Columnar Storage for PostgreSQL

## Architecture Overview

```mermaid
flowchart TB
    subgraph PostgreSQL
        SQL[SQL Query] --> Parser[PostgreSQL Parser]
        Parser --> Planner[PostgreSQL Planner]
        Planner --> CustomScan[MooncakeDuckDBScan]
        
        subgraph pg_mooncake["pg_mooncake Extension"]
            CustomScan --> DuckDBIntegration[DuckDB Integration Layer]
            TableAccessMethod[Table Access Method: 'columnstore'] --> DeltaWriter[Delta Lake Writer]
        end
    end
    
    subgraph Storage ["External Storage"]
        ParquetFiles[Parquet Files]
        DeltaLog[Delta Lake Transaction Log]
    end
    
    DuckDBIntegration --> ParquetFiles
    DuckDBIntegration --> DeltaLog
    DeltaWriter --> ParquetFiles
    DeltaWriter --> DeltaLog
    
    style pg_mooncake fill:#f9f,stroke:#333,stroke-width:2px
```

## Storage Engine: Columnar Format & Open Table Metadata

The pg_mooncake extension implements a new **table access method** called **`columnstore`**, allowing you to create tables with `USING columnstore` in PostgreSQL. Instead of storing data in PostgreSQL's heap pages, pg_mooncake writes table data as **columnar Parquet files** on disk (or object storage), with table metadata in **open formats** like **Delta Lake** (with planned support for **Apache Iceberg**) to track schema and transactions.

```mermaid
flowchart TD
    PostgreSQL[PostgreSQL Database] --> TableDef[Table Definition Metadata]
    TableDef --> MooncakeDir[PGDATA/mooncake_local_tables/]
    
    MooncakeDir --> TableDir["Table Directory (table_oid)"]
    TableDir --> ParquetFiles["Parquet Files (.parquet)"]
    TableDir --> DeltaLogDir["_delta_log/"]
    
    DeltaLogDir --> JsonLog["JSON Log Entries"]
    DeltaLogDir --> Checkpoints["Checkpoints"]
    
    style TableDef fill:#d0f0c0,stroke:#333
    style ParquetFiles fill:#c0d0f0,stroke:#333
    style DeltaLogDir fill:#f0c0c0,stroke:#333
```

Each columnstore table corresponds to a directory (e.g., under `PGDATA/mooncake_local_tables`) containing Parquet data files and a **_delta_log** for transactions. Only lightweight metadata (table definitions) lives in PostgreSQL itself – the heavy analytic data is external, which allows other engines to read it too (for example, pointing DuckDB or Spark at the same Delta/Iceberg directory).

### Transaction Handling

```mermaid
sequenceDiagram
    participant Client
    participant PG as PostgreSQL
    participant PGM as pg_mooncake
    participant Delta as Delta Lake
    
    Client->>PG: BEGIN TRANSACTION
    Client->>PG: INSERT/UPDATE/DELETE on columnstore table
    PG->>PGM: Handle data modification
    
    alt INSERT
        PGM->>PGM: Buffer rows in memory
        PGM->>Delta: Write new Parquet file (on flush)
        PGM->>Delta: Update transaction log
    else UPDATE/DELETE
        PGM->>Delta: Read affected Parquet file(s)
        PGM->>Delta: Rewrite file(s) without deleted/modified rows
        PGM->>Delta: Update transaction log (add new files, mark old as removed)
    end
    
    Client->>PG: COMMIT
    PG->>PGM: Finalize transaction
    PGM->>Delta: Commit changes to _delta_log
    
    Client->>PG: ROLLBACK
    PG->>PGM: Abort transaction
    PGM->>Delta: Discard pending changes
```

Under the hood, **inserts** into a columnstore table are **appended** as new Parquet files, and **updates/deletes** are handled in "delete/insert" fashion – the affected Parquet file(s) are rewritten without the deleted or modified rows, and the Delta Lake transaction log is updated to mark old files as removed. These operations occur transactionally – pg_mooncake integrates with PostgreSQL transactions so that writes are only committed to the Delta log on a successful commit (and aborted on rollback).

## Query Processing & Optimization

pg_mooncake **plugs into the PostgreSQL planner/executor** so that queries on columnstore tables are transparently handled by DuckDB's engine. It defines a custom scan plan node (a CustomScan) for columnstore tables, which appears in EXPLAIN as **"Custom Scan (MooncakeDuckDBScan)"**.

```mermaid
flowchart TD
    SQLQuery[SQL Query] --> PGParser[PostgreSQL Parser]
    PGParser --> PGAnalyzer[PostgreSQL Analyzer]
    PGAnalyzer --> PGPlanner[PostgreSQL Planner]
    
    PGPlanner --> TableCheck{Is table\ncolumnstore?}
    TableCheck -->|No| RegularPlan[Regular PostgreSQL Plan]
    TableCheck -->|Yes| CustomPlan[Custom Plan with MooncakeDuckDBScan]
    
    CustomPlan --> Pushdown["Push down filters & projections"]
    Pushdown --> DuckDBQuery["Generate DuckDB Query"]
    
    DuckDBQuery --> FilePruning["File Pruning (using statistics)"]
    FilePruning --> VectorizedExec["Vectorized Execution via DuckDB"]
    VectorizedExec --> ResultConversion["Convert DuckDB results to PostgreSQL tuples"]
    ResultConversion --> PGExecutor["Return to PostgreSQL Executor"]
    
    style TableCheck fill:#f9f,stroke:#333
    style Pushdown fill:#c0d0f0,stroke:#333
    style VectorizedExec fill:#c0d0f0,stroke:#333
```

During planning, the extension detects when a table is columnstore and replaces the normal SeqScan with this custom node. The custom plan node's logic uses DuckDB to execute the scan in a **vectorized** manner. Essentially, pg_mooncake takes the **filter conditions and projections** from the PostgreSQL query and **pushes them down** into an **embedded DuckDB query plan**. In other words, pg_mooncake turns the scan of a Parquet-backed table into a DuckDB operation that reads only the needed columns and applies WHERE clauses using DuckDB's efficient vectorized scan.

### Predicate Pushdown and File Skipping

```mermaid
flowchart TD
    Query["SELECT * FROM sales WHERE date > '2023-01-01' AND region = 'WEST'"] --> PGMooncake[pg_mooncake]
    
    PGMooncake --> Statistics["Check file statistics (min/max values)"]
    Statistics --> FileSkip["Skip files that can't match predicate"]
    
    subgraph "Files in storage"
        File1["File1.parquet\ndate: 2022-01 to 2022-06\nregion: EAST, WEST"]
        File2["File2.parquet\ndate: 2023-01 to 2023-06\nregion: EAST, SOUTH"]
        File3["File3.parquet\ndate: 2023-01 to 2023-06\nregion: WEST, NORTH"]
    end
    
    FileSkip -->|Skip (date range doesn't match)| File1
    FileSkip -->|Skip (region doesn't match)| File2
    FileSkip -->|Process (matches all predicates)| File3
    
    File3 --> DuckDBScan["DuckDB vectorized scan\nwith pushed-down predicates"]
    DuckDBScan --> Results[Return matching rows]
```

pg_mooncake's columnar format brings typical warehouse optimizations. Data is stored compressed in Parquet, and pg_mooncake keeps **column statistics** (like min/max values per file) to speed up reads. This allows **predicate pushdown** and **file skipping**: if a query's filter can be checked against a file's min/max and found to exclude that file, pg_mooncake can skip opening it.

## Integration with DuckDB

```mermaid
flowchart LR
    subgraph PostgreSQL["PostgreSQL Process"]
        PGQuery["PostgreSQL Query"]
        TAM["Table Access Method (columnstore)"]
        
        subgraph pg_mooncake["pg_mooncake Extension"]
            DuckDBEmbed["Embedded DuckDB Instance"]
            ScanFunction["columnstore_scan() Table Function"]
            DuckDBAPI["DuckDB C++ API"]
        end
    end
    
    subgraph Storage["Storage Layer"]
        DeltaDir["Delta Lake Directory"]
        ParquetData["Parquet Data Files"]
    end
    
    PGQuery --> TAM
    TAM --> DuckDBEmbed
    DuckDBEmbed --> ScanFunction
    ScanFunction --> DuckDBAPI
    DuckDBAPI --> ParquetData
    DuckDBAPI --> DeltaDir
    
    style DuckDBEmbed fill:#f9d,stroke:#333
    style ScanFunction fill:#f9d,stroke:#333
```

pg_mooncake achieves its magic by **embedding DuckDB** inside the PostgreSQL process. The project includes DuckDB as a library (via the `pg_duckdb` submodule) so that an instance of DuckDB can be invoked at runtime. When you install pg_mooncake, it builds a `libduckdb` and ships it along with the extension, effectively bundling DuckDB's engine into PostgreSQL.

At a code level, pg_mooncake registers a **DuckDB table function** called `columnstore_scan` which DuckDB uses to access PostgreSQL columnstore tables. This table function tells DuckDB how to find and read the Parquet files for a given table OID, and it integrates with DuckDB's optimizer by providing statistics like row count.

## Data Flow Across Multiple Systems

```mermaid
flowchart TB
    subgraph PostgreSQL["PostgreSQL + pg_mooncake"]
        PG[(PostgreSQL Database)]
        PGCS["Columnstore Tables"]
    end
    
    subgraph Storage["Data Lake Storage"]
        Delta[("Delta Lake Format")]
        Parquet["Parquet Files"]
    end
    
    subgraph Analytics["Analytics Engines"]
        DuckDB["DuckDB"]
        Spark["Apache Spark"]
        Pandas["Pandas"]
    end
    
    PG <-->|Table Definition| PGCS
    PGCS <-->|Writes/Reads| Delta
    Delta <-->|Tracks| Parquet
    
    DuckDB -->|Reads| Parquet
    DuckDB -->|Understands| Delta
    Spark -->|Reads| Parquet
    Spark -->|Understands| Delta
    Pandas -->|Reads| Parquet
    
    style PGCS fill:#f9f,stroke:#333
    style Delta fill:#c0d0f0,stroke:#333
    style Parquet fill:#d0f0c0,stroke:#333
```

Because the on-disk format is open, a pg_mooncake table is essentially a Delta Lake table on disk – you can find its files via `SELECT * FROM mooncake.columnstore_tables` and directly query them with Pandas, DuckDB, or Spark outside PostgreSQL.

## Performance Optimization Flow

```mermaid
flowchart TD
    Query["Analytic Query"] --> ColumnPruning["Column Pruning\n(read only needed columns)"]
    ColumnPruning --> PredicatePushdown["Predicate Pushdown\n(filter early)"]
    PredicatePushdown --> FilePruning["File Pruning\n(skip files using min/max stats)"]
    FilePruning --> Vectorization["Vectorized Processing\n(process 1024 values at once)"]
    Vectorization --> SIMD["SIMD Acceleration\n(CPU parallel processing)"]
    SIMD --> LateMat["Late Materialization\n(keep data in columnar format)"]
    LateMat --> Result["Fast Analytic Results"]
    
    style ColumnPruning fill:#c0d0f0,stroke:#333
    style PredicatePushdown fill:#c0d0f0,stroke:#333
    style FilePruning fill:#c0d0f0,stroke:#333
    style Vectorization fill:#f9d,stroke:#333
    style SIMD fill:#f9d,stroke:#333
```

By relying on DuckDB's robust engine, pg_mooncake implements complex features with relatively little new code. The source code for pg_mooncake primarily wires together PostgreSQL hooks (like the Table AM handler and a planner hook) with DuckDB's C++ API. The heavy scanning logic is deferred to DuckDB, which reads Parquet and even supports reading remote files (S3) via DuckDB's built-in S3 support or via the Rust Delta Lake integration.

## Summary

pg_mooncake offloads columnstore query execution to an embedded DuckDB engine using the pg_duckdb project. The extension defines custom DuckDB table/functions (e.g., `columnstore_scan`) and hooks into PostgreSQL's query plan to invoke them. This clever architecture lets PostgreSQL act as an orchestrator, while DuckDB's vectorized execution and file format support do the hard work – enabling **fast analytics in PostgreSQL with minimal fuss**.

## Implementation Details

### Storage Engine
- Implements a custom Table Access Method (`columnstore`)
- Writes data as columnar Parquet files
- Uses Delta Lake for metadata and transaction tracking
- Handles updates/deletes by rewriting affected files
- Provides ACID guarantees via Delta Lake transaction log

### Query Execution
- Custom scan node (`MooncakeDuckDBScan`) replaces standard scan
- Pushes filters and projections to DuckDB
- Uses file-level statistics to skip irrelevant files
- Processes data in vectorized batches (not row-by-row)
- Converts DuckDB result vectors to PostgreSQL tuples

### DuckDB Integration
- Embeds DuckDB as a library within PostgreSQL
- Registers a custom `columnstore_scan` function in DuckDB
- Provides file statistics to DuckDB's optimizer
- Uses DuckDB's efficient Parquet reader
- Leverages DuckDB's vectorized execution engine

### Performance Features
- Column pruning (read only required columns)
- Predicate pushdown (filter early in the process)
- File skipping (avoid reading irrelevant files)
- Compression at rest (Parquet's built-in compression)
- Vectorized processing (process batches of values)
- SIMD acceleration (use CPU parallel instructions)
- Late materialization (keep data in columnar format longer)