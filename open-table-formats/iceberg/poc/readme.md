## Apache Iceberg POC - Why and How

### Why?

The purpose of this Proof of Concept (POC) is to evaluate the feasibility and benefits of adopting Apache Iceberg in a data infrastructure. [Apache Iceberg](https://iceberg.apache.org/) is an open, high-performance table format designed to handle large-scale analytics and bring consistency, scalability, and reliability to big data workloads.

#### The key reasons for exploring this POC includes exploring the following concepts:

- **Scalable Table Management:** Iceberg supports efficient metadata management which allows for quick, scalable data operations on large datasets.

- **Improved Reliability:** Iceberg supports ACID compliance and snapshot isolation, ensuring safer concurrent operations and reliable data rollbacks.

- **Query Optimization:** Iceberg supports efficient query planning with metadata-driven optimizations, potentially reducing query latency and resource usage.

- **Flexible Integration:** Compatible with popular query engines like Apache Spark, Presto, Trino, and Hive, ensuring minimal friction in adoption.

### How?

#### At a high-level, the POC includes:

- **Setup and Configuration:**
Using Docker Compose simplifies the deployment of the necessary infrastructure, eliminating complexities associated with manual setup and configuration.

- **Table Management:** Creating Iceberg tables to demonstrate schema evolution, partitioning strategies, and metadata management.

- **Data Operations:** Ingesting data into Iceberg tables using Apache Spark, illustrating ease of use and performance during bulk and incremental operations.

- **Performing basic CRUD (Create, Read, Update, Delete) operations**: To showcase Iceberg’s ACID properties.

- **Querying Capabilities:** Running analytic queries using standard SQL engines compatible with Iceberg (e.g., Spark SQL, Clickhouse) to demonstrate interoperability and performance improvements.


### Understanding Iceberg!!

#### This POC also includes evaluating and understanding:

- **Catalog Implementations:** Exploring various catalog implementations such as Rest, Hadoop Tables, Unity, and Nessie, and assessing their pros and cons for specific use cases.

- **Compaction:** Assessing Iceberg’s compaction capabilities to efficiently manage data files and optimize storage.

- **Write and Query Engines:** Evaluating different data processing frameworks (e.g., Apache Spark, Apache Flink) and query engines (e.g., Spark SQL, Presto, Trino) to understand their compatibility and performance with Iceberg tables.

This POC aims to provide clarity on the practical benefits and operational ease of Apache Iceberg, guiding future architectural decisions.