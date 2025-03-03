I'll conduct deep research on how pg\_mooncake works, focusing on its storage engine, query optimization techniques, and its integration with DuckDB. I'll provide both high-level and code-level insights, citing relevant source files and documentation.

I'll update you once I have a detailed breakdown.

Research completed in 8m · 25 sources

**Storage Engine (Columnar Format & Open Table Metadata):** The pg\_mooncake extension implements a new **table access method** called **`columnstore`**, which means you can create tables using `USING columnstore` in Postgres​

[postgresql.jp](https://www.postgresql.jp/sites/default/files/2024-12/A4_PostgreSQL%20Conference%20Japan%202024%20A4%20%E5%88%97%E6%8C%87%E5%90%91%E5%BE%B9%E5%BA%95%E6%AF%94%E8%BC%83%2020241205.pdf#:~:text=%E2%9C%93%E3%82%A8%E3%82%AF%E3%82%B9%E3%83%86%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%B3%E5%90%8D%EF%BC%9A%20pg_mooncake%20%E2%9C%93Table%20Access%20Method,t%20%282%20rows)

​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake#:~:text=2)

. Instead of storing data in PostgreSQL’s heap pages, pg\_mooncake writes table data out as **columnar Parquet files** on disk (or object storage), with table metadata in **open formats** like **Delta Lake** (and planned **Apache Iceberg**) to track schema and transactions​

[neon.tech](https://neon.tech/docs/extensions/pg_mooncake#:~:text=,with%20Icebergor%20Delta%20Lake%20metadata)

​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake#:~:text=Find%20your%20columnstore%20table%20location%3A)

. In practice, each columnstore table corresponds to a directory (e.g. under `PGDATA/mooncake_local_tables`) containing Parquet data files and a **\_delta\_log** for transactions​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake#:~:text=Find%20your%20columnstore%20table%20location%3A)

. Only lightweight metadata (table definitions, etc.) lives in Postgres itself​

[neon.tech](https://neon.tech/docs/extensions/pg_mooncake#:~:text=execution)

– the heavy analytic data is external, which allows other engines to read it too (for example, pointing DuckDB or Spark at the same Delta/Iceberg directory)​

[motherduck.com](https://motherduck.com/blog/pg-mooncake-columnstore/#:~:text=What%27s%20the%20MotherDuck%20connection%3F)

.

_Under the hood,_ **inserts** into a columnstore table are **appended** as new Parquet files, and **updates/deletes** are handled in “delete/insert” fashion – the affected Parquet file(s) are rewritten without the deleted or modified rows, and the Delta Lake transaction log is updated to mark old files as removed​

[mooncake.dev](https://www.mooncake.dev/blog/how-we-built-pgmooncake#:~:text=Image%3A%20Parquet%20File%20Format)

. (In the current implementation, even a single-row delete will rewrite an entire Parquet file, which is the standard approach in data lakes​

[mooncake.dev](https://www.mooncake.dev/blog/how-we-built-pgmooncake#:~:text=Image%3A%20Parquet%20File%20Format)

.) These operations occur transactionally – pg\_mooncake integrates with Postgres transactions so that writes are only committed to the Delta log on a successful commit (and aborted on rollback)​

[mooncake.dev](https://www.mooncake.dev/blog/how-we-built-pgmooncake#:~:text=It%20supports%20transactional%20inserts%2C%20updates%2C,Databricks%20as%20a%20Postgres%20developer)

. The extension uses the Delta Lake metadata to ensure **ACID** semantics: for example, it writes JSON log entries for each commit and uses Delta’s versioning to make changes atomic and isolated. (The project includes a Rust-based component to handle Delta Lake operations – the build uses Cargo to compile a module for writing/reading Delta logs​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake/blob/main/Makefile#:~:text=match%20at%20L678%20cargo%20build,path%3D%24%28DELTA_DIR%29%2FCargo.toml%20%24%28CARGO_FLAGS)

.) Because the on-disk format is open, a pg\_mooncake table is essentially a Delta Lake table on disk – you can find its files via `SELECT * FROM mooncake.columnstore_tables` and directly query them with Pandas, DuckDB, or Spark outside Postgres​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake#:~:text=Find%20your%20columnstore%20table%20location%3A)

.

**Storage & Retrieval Optimizations:** pg\_mooncake’s columnar format brings typical warehouse optimizations. Data is stored compressed in Parquet, and pg\_mooncake keeps **column statistics** (like min/max values per file) to speed up reads. In the code, a `DataFileStatistics` cache is maintained for each Parquet file in a columnstore table​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake/issues/124#:~:text=Yes%2C%20passing%20cardinality%20to%20DuckDB,is%20better)

. This allows **predicate pushdown** and **file skipping**: if a query’s filter can be checked against a file’s min/max and found to exclude that file, pg\_mooncake can skip opening it. (The developers note that these file-level stats make many traditional table partitions unnecessary, since min/max pruning achieves a similar effect​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake#:~:text=,Partitioned%20tables)

.) The extension is evolving to handle small writes efficiently as well – the upcoming v0.2 uses an in-memory row-store buffer for trickle inserts, flushing a batch to Parquet only when enough data accumulates, to avoid generating tiny Parquet files for every small transaction​

[github.com](https://github.com/digoal/blog/blob/master/202412/20241231_02.md#:~:text=3%E3%80%81%E5%B0%8F%E6%89%B9%E9%87%8F%E6%8F%92%E5%85%A5%E7%9A%84%E8%A1%8C%E5%AD%98%E5%82%A8%E7%BC%93%E5%86%B2%E5%8C%BA)

​

[github.com](https://github.com/digoal/blog/blob/master/202412/20241231_02.md#:~:text=%E9%80%BB%E8%BE%91%E5%A4%8D%E5%88%B6%E5%B8%A6%E6%9D%A5%E4%B8%80%E4%B8%AA%E6%8C%91%E6%88%98%EF%BC%9A%E5%A6%82%E4%BD%95%E5%9C%A8%E4%B8%8D%E4%B8%BA%E6%AF%8F%E4%B8%AA%E4%BA%8B%E5%8A%A1%E7%94%9F%E6%88%90%E6%96%B0Parquet%E6%96%87%E4%BB%B6%E5%92%8CDelta%20Lake%E6%97%A5%E5%BF%97%E7%9A%84%E6%83%85%E5%86%B5%E4%B8%8B%E5%A4%84%E7%90%86%E9%A2%91%E7%B9%81%E7%9A%84%E5%B0%8F%E6%89%B9%E9%87%8F%E6%8F%92%E5%85%A5%EF%BC%9F)

. In summary, pg\_mooncake’s storage engine writes out columnar files with open-format metadata, and employs metadata caching, compression, and late materialization to optimize scan performance.

**Query Processing & Optimization:** pg\_mooncake **plugs into the PostgreSQL planner/executor** so that queries on columnstore tables are transparently handled by DuckDB’s engine. It defines a custom scan plan node (a CustomScan) for columnstore tables, which appears in EXPLAIN as **“Custom Scan (MooncakeDuckDBScan)”**​

[dbi-services.com](https://www.dbi-services.com/blog/pg_mooncake-another-columnar-storage-for-postgresql/#:~:text=,DuckDB%20Execution%20Plan)

. During planning, the extension detects when a table is columnstore and replaces the normal SeqScan with this custom node. The custom plan node’s logic (implemented in the source file `columnstore_scan.cpp`) uses DuckDB to execute the scan in a **vectorized** manner. Essentially, pg\_mooncake takes the **filter conditions and projections** from the Postgres query and **pushes them down** into an **embedded DuckDB query plan**. We can see this in an example EXPLAIN output: the DuckDB plan shows a `TABLE_SCAN` on a `COLUMNSTORE_SCAN` function with the projected columns and a pushed-down filter `a=1`​

[dbi-services.com](https://www.dbi-services.com/blog/pg_mooncake-another-columnar-storage-for-postgresql/#:~:text=%E2%94%82%20%20%20%20,%E2%94%82)

. In other words, pg\_mooncake turns the scan of a Parquet-backed table into a DuckDB operation that reads only the needed columns and applies WHERE clauses using DuckDB’s efficient vectorized scan. This pushdown greatly reduces data movement into PostgreSQL. Joins or other operations that involve regular Postgres tables will fall back to Postgres for those parts, but pg\_mooncake will still accelerate the columnstore side. (The extension supports joining columnstore tables with heap tables, treating the columnstore scan as just another plan node outputting tuples​

[neon.tech](https://neon.tech/docs/extensions/pg_mooncake#:~:text=,Joins%20with%20regular%20Postgres%20tables)

.)

Because DuckDB’s engine is set up to handle large analytical scans, pg\_mooncake benefits from **DuckDB’s query optimizer and vectorized execution** techniques. DuckDB uses **vectorized processing**, late materialization, and efficient columnar operators, so when pg\_mooncake hands over a scan or aggregate to DuckDB, it executes in bulk on chunks of, say, 1024 values at a time instead of row-by-row​

[mooncake.dev](https://www.mooncake.dev/blog/how-we-built-pgmooncake#:~:text=Numerous%20attempts%20have%20been%20made,execution%20to%20leverage%20the%20format)

. This is a key reason analytics on pg\_mooncake tables can be orders of magnitude faster than on vanilla Postgres tables – the heavy lifting is done by DuckDB’s SIMD-optimized, vectorized pipeline. The pg\_mooncake developers explicitly note that analytical queries on columnstore tables run with performance comparable to DuckDB on Parquet​

[motherduck.com](https://motherduck.com/blog/pg-mooncake-columnstore/#:~:text=DuckDB%20is%20the%20default%20execution,to%20running%20pg_duckdb%20on%20Parquet)

. In fact, you can even use some of DuckDB’s specialized SQL functions (e.g. `approx_count_distinct`) in Postgres when querying a columnstore table​

[neon.tech](https://neon.tech/docs/extensions/pg_mooncake#:~:text=,Lake%20tables%20from%20Postgres%20tables)

– those get routed to DuckDB for execution as well. Before handing control to DuckDB, pg\_mooncake may also apply its file-statistics filters as noted, to tell DuckDB to skip reading certain row groups or files (it plans to use DuckDB’s `parquet_scan.explicit_cardinality` and similar parameters to pass along row count estimates and skip indexes)​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake/issues/124#:~:text=edited)

​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake/issues/124#:~:text=Yes%2C%20passing%20cardinality%20to%20DuckDB,is%20better)

. Overall, query execution is a collaborative process: Postgres handles the SQL parsing and overall plan, but the pg\_mooncake custom scan node **rewrites the scan part of the plan** to use DuckDB’s columnar execution engine, pushing down filters/projections and retrieving batches of tuples in a vectorized way.

**Integration with DuckDB (pg\_duckdb & Storage Extension Details):** pg\_mooncake achieves its magic by **embedding DuckDB** inside the Postgres process. The project includes DuckDB as a library (via the `pg_duckdb` submodule) so that an instance of DuckDB can be invoked at runtime​

[motherduck.com](https://motherduck.com/blog/pg-mooncake-columnstore/#:~:text=DuckDB%20is%20the%20default%20execution,to%20running%20pg_duckdb%20on%20Parquet)

​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake#:~:text=Columnstore%20Table%20in%20Postgres,0)

. When you install pg\_mooncake, it builds a `libduckdb` and ships it along with the extension, effectively bundling DuckDB’s engine into Postgres. The integration is designed to be modular – pg\_mooncake’s authors mention that the extension will seamlessly track future pg\_duckdb updates, since it largely reuses DuckDB’s own integration layer​

[motherduck.com](https://motherduck.com/blog/pg-mooncake-columnstore/#:~:text=DuckDB%20is%20the%20default%20execution,to%20running%20pg_duckdb%20on%20Parquet)

. At a code level, pg\_mooncake registers a **DuckDB table function** called `columnstore_scan` (implemented in `src/columnstore/columnstore_scan.cpp`) which DuckDB uses to access Postgres columnstore tables​

[dbi-services.com](https://www.dbi-services.com/blog/pg_mooncake-another-columnar-storage-for-postgresql/#:~:text=%E2%94%82%20%20%20%20%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80%E2%94%80,%E2%94%82)

. This table function tells DuckDB how to find and read the Parquet files for a given table OID, and it integrates with DuckDB’s optimizer by providing statistics like row count (the team added a custom cardinality estimator for it)​

[github.com](https://github.com/Mooncake-Labs/pg_mooncake/issues/124#:~:text=We%20just%20need%20to%20implement,Labs%2Fpg_mooncake%2Fblob%2Fmain%2Fsrc%2Fcolumnstore%2Fexecution%2Fcolumnstore_scan.cpp%23L144)

. In essence, pg\_mooncake treats the columnstore table as an **external table in DuckDB** – DuckDB knows how to scan it via `columnstore_scan`, using the Parquet reader under the hood. The Postgres side invokes DuckDB to perform the scan (or other operations) and then returns the resulting tuples into the Postgres executor. This was described by the authors as implementing pg\_mooncake “as a DuckDB **storage extension**”​

[motherduck.com](https://motherduck.com/blog/pg-mooncake-columnstore/#:~:text=DuckDB%20is%20the%20default%20execution,to%20running%20pg_duckdb%20on%20Parquet)

. They were able to leverage DuckDB’s extension API so that they _did not have to modify DuckDB’s core engine at all_, but merely extended it to understand Postgres columnstore tables.

When a query runs, each pg\_mooncake scan node establishes a DuckDB **connection/context** (usually one per session or per query) and calls the `columnstore_scan` function inside DuckDB to produce an intermediate result. DuckDB will scan the Parquet files, apply any pushed-down filters, and produce output in vectors. The pg\_mooncake code then **yields these results back to the Postgres executor**. (Internally this is done by retrieving DuckDB result chunks and converting them into Postgres Tuples or Datum arrays that feed into a `TupleTableSlot` – the integration code handles mapping DuckDB types to Postgres types.) All of this is hidden behind the scenes – to the user, it just looks like a fast table. For example, an analytic query `SELECT SUM(quantity) FROM sales` on a columnstore table will invoke DuckDB to do a vectorized scan and aggregation on the Parquet data, and only the final sum is handed back to Postgres. By relying on DuckDB’s robust engine, pg\_mooncake implements complex features with relatively little new code. The source code for pg\_mooncake primarily wires together Postgres hooks (like the Table AM handler and a planner hook) with DuckDB’s C++ API. The heavy scanning logic is deferred to DuckDB, which reads Parquet and even supports reading remote files (S3) via DuckDB’s built-in S3 support or via the Rust Delta Lake integration. In summary, **pg\_mooncake offloads columnstore query execution to an embedded DuckDB engine** using the pg\_duckdb project. The extension defines custom DuckDB table/functions (e.g. `columnstore_scan`) and hooks into Postgres’s query plan to invoke them. This clever architecture lets Postgres act as an orchestrator, while DuckDB’s vectorized execution and file format support do the hard work – enabling **fast analytics in Postgres with minimal fuss**​

[motherduck.com](https://motherduck.com/blog/pg-mooncake-columnstore/#:~:text=DuckDB%20is%20the%20default%20execution,to%20running%20pg_duckdb%20on%20Parquet)

​

[dbi-services.com](https://www.dbi-services.com/blog/pg_mooncake-another-columnar-storage-for-postgresql/#:~:text=,DuckDB%20Execution%20Plan)

.

**Sources:**

*   Mooncake Labs, _pg\_mooncake – Columnstore Table in Postgres (GitHub README)_​
    
    [github.com](https://github.com/Mooncake-Labs/pg_mooncake#:~:text=Find%20your%20columnstore%20table%20location%3A)
    
    ​
    
    [mooncake.dev](https://www.mooncake.dev/blog/how-we-built-pgmooncake#:~:text=Image%3A%20Parquet%20File%20Format)
    
*   Mooncake Labs, _How we built pg\_mooncake (blog)_​
    
    [mooncake.dev](https://www.mooncake.dev/blog/how-we-built-pgmooncake#:~:text=Numerous%20attempts%20have%20been%20made,execution%20to%20leverage%20the%20format)
    
    ​
    
    [mooncake.dev](https://www.mooncake.dev/blog/how-we-built-pgmooncake#:~:text=The%20first%20decision%20to%20make,directly%20readable%20by%20most%20engines)
    
*   MotherDuck Blog, _pg\_mooncake: Columnstore Tables with DuckDB Execution_​
    
    [motherduck.com](https://motherduck.com/blog/pg-mooncake-columnstore/#:~:text=DuckDB%20is%20the%20default%20execution,to%20running%20pg_duckdb%20on%20Parquet)
    
    ​
    
    [motherduck.com](https://motherduck.com/blog/pg-mooncake-columnstore/#:~:text=DuckDB%20is%20the%20default%20execution,to%20running%20pg_duckdb%20on%20Parquet)
    
*   Neon Tech Docs – _pg\_mooncake extension_​
    
    [neon.tech](https://neon.tech/docs/extensions/pg_mooncake#:~:text=execution)
    
    ​
    
    [neon.tech](https://neon.tech/docs/extensions/pg_mooncake#:~:text=,Lake%20tables%20from%20Postgres%20tables)
    
*   pg\_mooncake source code (GitHub issues/discussions referencing implementation): Table AM handler and storage format​
    
    [postgresql.jp](https://www.postgresql.jp/sites/default/files/2024-12/A4_PostgreSQL%20Conference%20Japan%202024%20A4%20%E5%88%97%E6%8C%87%E5%90%91%E5%BE%B9%E5%BA%95%E6%AF%94%E8%BC%83%2020241205.pdf#:~:text=%E2%9C%93%E3%82%A8%E3%82%AF%E3%82%B9%E3%83%86%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%B3%E5%90%8D%EF%BC%9A%20pg_mooncake%20%E2%9C%93Table%20Access%20Method,t%20%282%20rows)
    
    ​
    
    [github.com](https://github.com/Mooncake-Labs/pg_mooncake/issues/124#:~:text=Yes%2C%20passing%20cardinality%20to%20DuckDB,is%20better)
    
    , Custom DuckDB scan node and pushdown logic​
    
    [dbi-services.com](https://www.dbi-services.com/blog/pg_mooncake-another-columnar-storage-for-postgresql/#:~:text=%E2%94%82%20%20%20%20,%E2%94%82)
    
    ​
    
    [github.com](https://github.com/Mooncake-Labs/pg_mooncake/issues/124#:~:text=edited)
    
    .