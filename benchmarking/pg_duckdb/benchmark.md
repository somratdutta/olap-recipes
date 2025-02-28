# Benchmarking pg_duckdb for an OLAP Use Case

## **Introduction**

Benchmarking **pg_duckdb**, a DuckDB-powered Postgres extension, for an **OLAP (Online Analytical Processing) use case** serves as a critical performance evaluation. The goal is to demonstrate how pg_duckdb enhances PostgreSQL's analytical query performance by leveraging:

- DuckDB's vectorized execution engine
- Columnar storage capabilities
- Seamless integration with object storage
- Advanced analytics extensions

This analysis helps understand how pg_duckdb transforms PostgreSQL into a high-performance analytical database platform.

## **Methodology**

We used **ClickBench pg_duckdb** benchmark ([GitHub](https://github.com/ClickHouse/ClickBench/tree/main/pg_duckdb)) for performance testing, utilizing a Docker-based setup for consistent and reproducible results.

### **Benchmark Environment**

- **Deployment Method:** Docker container
- **Docker Image:** `pgduckdb/pgduckdb:16-main`
- **Dataset:** `hits.parquet` from ClickBench
- **Data Format:** Parquet (columnar storage format)

Key benchmark script components:
```sh
# Docker run command
docker run -d --name pgduck -p 5432:5432 \
    -e POSTGRES_PASSWORD=duckdb \
    -v ./hits.parquet:/tmp/hits.parquet \
    pgduckdb/pgduckdb:16-main

# Dataset preparation
wget https://datasets.clickhouse.com/hits_compatible/athena/hits.parquet
```



The benchmark includes **43 queries** that test pg_duckdb's performance on:
- **Complex aggregations**
- **Text search**
- **Multi-source data analytics**
- **Storage-efficient querying**


## **Benchmark Machine Specifications**

The entire benchmark was run on a virtual machine with the following specifications:

| Component  | Specification  |
|------------|---------------|
| **CPU**    | 16 vCPUs      |
| **Memory** | 32 GB         |
| **Storage**| 500 GB        |



## **Results**

### **Table Size**

Storage breakdown for the pg_duckdb Docker container:

```sh
# Docker container storage analysis
/var/lib/postgresql/data:   40,824,304 bytes
/tmp/hits.parquet:         14,779,976,446 bytes
Total:                     14,820,800,750 bytes

# Parquet file size: ~14.8 GB
# PostgreSQL data size: ~40.8 MB
```

### **Query Performance**
| Query | Run 1 (seconds) | Run 2 (seconds) | Run 3 (seconds) |
|-------|----------------|----------------|----------------|
| SELECT COUNT(*) FROM hits; | 0.366684 | 0.263955 | 0.264255 |
| SELECT COUNT(*) FROM hits WHERE AdvEngineID <> 0; | 0.314257 | 0.240729 | 0.22511 |
| SELECT SUM(AdvEngineID), COUNT(*), AVG(ResolutionWidth) FROM hits; | 0.424459 | 0.26951 | 0.329512 |
| SELECT AVG(UserID) FROM hits; | 0.626797 | 0.259229 | 0.295228 |
| SELECT COUNT(DISTINCT UserID) FROM hits; | 0.778875 | 0.589633 | 0.594088 |
| SELECT COUNT(DISTINCT SearchPhrase) FROM hits; | 0.930474 | 0.737917 | 0.721549 |
| SELECT MIN(EventDate), MAX(EventDate) FROM hits; | 1.88753 | 1.84881 | 1.82388 |
| SELECT AdvEngineID, COUNT(*) FROM hits WHERE AdvEngineID <> 0 GROUP BY AdvEngineID ORDER BY COUNT(*) DESC; | 0.330349 | 0.235065 | 0.24299 |
| SELECT RegionID, COUNT(DISTINCT UserID) AS u FROM hits GROUP BY RegionID ORDER BY u DESC LIMIT 10; | 0.914948 | 0.679865 | 0.636626 |
| SELECT RegionID, SUM(AdvEngineID), COUNT(*) AS c, AVG(ResolutionWidth), COUNT(DISTINCT UserID) FROM hits GROUP BY RegionID ORDER BY c DESC LIMIT 10; | 1.13603 | 0.796507 | 0.813269 |
| SELECT MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhoneModel ORDER BY u DESC LIMIT 10; | 0.643921 | 0.347555 | 0.349029 |
| SELECT MobilePhone, MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhone, MobilePhoneModel ORDER BY u DESC LIMIT 10; | 0.719643 | 0.400602 | 0.42697 |
| SELECT SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 0.936059 | 0.830889 | 0.759301 |
| SELECT SearchPhrase, COUNT(DISTINCT UserID) AS u FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY u DESC LIMIT 10; | 1.41804 | 1.10545 | 1.10471 |
| SELECT SearchEngineID, SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, SearchPhrase ORDER BY c DESC LIMIT 10; | 1.08688 | 0.87287 | 0.819588 |
| SELECT UserID, COUNT(*) FROM hits GROUP BY UserID ORDER BY COUNT(*) DESC LIMIT 10; | 0.847643 | 0.574105 | 0.575538 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 1.6454 | 1.34188 | 1.33371 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase LIMIT 10; | 1.48181 | 1.13454 | 1.13222 |
| SELECT UserID, extract(minute FROM EventTime) AS m, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, m, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 6.00857 | 5.55844 | 5.55417 |
| SELECT UserID FROM hits WHERE UserID = 435090932899640449; | 0.573701 | 0.251703 | 0.250102 |
| SELECT COUNT(*) FROM hits WHERE URL LIKE '%google%'; | 2.45155 | 1.86776 | 1.91386 |
| SELECT SearchPhrase, MIN(URL), COUNT(*) AS c FROM hits WHERE URL LIKE '%google%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 2.23889 | 1.23946 | 1.24799 |
| SELECT SearchPhrase, MIN(URL), MIN(Title), COUNT(*) AS c, COUNT(DISTINCT UserID) FROM hits WHERE Title LIKE '%Google%' AND URL NOT LIKE '%.google.%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 3.4978 | 2.26366 | 2.25949 |
| SELECT * FROM hits WHERE URL LIKE '%google%' ORDER BY EventTime LIMIT 10; | 11.0868 | 9.19289 | 9.19175 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime LIMIT 10; | 1.51711 | 1.13849 | 1.10596 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY SearchPhrase LIMIT 10; | 0.733819 | 0.522039 | 0.551567 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime, SearchPhrase LIMIT 10; | 1.49428 | 1.10039 | 1.13736 |
| SELECT CounterID, AVG(length(URL)) AS l, COUNT(*) AS c FROM hits WHERE URL <> '' GROUP BY CounterID HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 2.45577 | 1.89263 | 1.893 |
| SELECT REGEXP_REPLACE(Referer, '^https?://(?:www\.)?([^/]+)/.*$', '\1') AS k, AVG(length(Referer)) AS l, COUNT(*) AS c, MIN(Referer) FROM hits WHERE Referer <> '' GROUP BY k HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 9.00478 | 8.78448 | 8.94547 |
| SELECT SUM(ResolutionWidth), SUM(ResolutionWidth + 1), SUM(ResolutionWidth + 2), SUM(ResolutionWidth + 3), SUM(ResolutionWidth + 4), SUM(ResolutionWidth + 5), SUM(ResolutionWidth + 6), SUM(ResolutionWidth + 7), SUM(ResolutionWidth + 8), SUM(ResolutionWidth + 9), SUM(ResolutionWidth + 10), SUM(ResolutionWidth + 11), SUM(ResolutionWidth + 12), SUM(ResolutionWidth + 13), SUM(ResolutionWidth + 14), SUM(ResolutionWidth + 15), SUM(ResolutionWidth + 16), SUM(ResolutionWidth + 17), SUM(ResolutionWidth + 18), SUM(ResolutionWidth + 19), SUM(ResolutionWidth + 20), SUM(ResolutionWidth + 21), SUM(ResolutionWidth + 22), SUM(ResolutionWidth + 23), SUM(ResolutionWidth + 24), SUM(ResolutionWidth + 25), SUM(ResolutionWidth + 26), SUM(ResolutionWidth + 27), SUM(ResolutionWidth + 28), SUM(ResolutionWidth + 29), SUM(ResolutionWidth + 30), SUM(ResolutionWidth + 31), SUM(ResolutionWidth + 32), SUM(ResolutionWidth + 33), SUM(ResolutionWidth + 34), SUM(ResolutionWidth + 35), SUM(ResolutionWidth + 36), SUM(ResolutionWidth + 37), SUM(ResolutionWidth + 38), SUM(ResolutionWidth + 39), SUM(ResolutionWidth + 40), SUM(ResolutionWidth + 41), SUM(ResolutionWidth + 42), SUM(ResolutionWidth + 43), SUM(ResolutionWidth + 44), SUM(ResolutionWidth + 45), SUM(ResolutionWidth + 46), SUM(ResolutionWidth + 47), SUM(ResolutionWidth + 48), SUM(ResolutionWidth + 49), SUM(ResolutionWidth + 50), SUM(ResolutionWidth + 51), SUM(ResolutionWidth + 52), SUM(ResolutionWidth + 53), SUM(ResolutionWidth + 54), SUM(ResolutionWidth + 55), SUM(ResolutionWidth + 56), SUM(ResolutionWidth + 57), SUM(ResolutionWidth + 58), SUM(ResolutionWidth + 59), SUM(ResolutionWidth + 60), SUM(ResolutionWidth + 61), SUM(ResolutionWidth + 62), SUM(ResolutionWidth + 63), SUM(ResolutionWidth + 64), SUM(ResolutionWidth + 65), SUM(ResolutionWidth + 66), SUM(ResolutionWidth + 67), SUM(ResolutionWidth + 68), SUM(ResolutionWidth + 69), SUM(ResolutionWidth + 70), SUM(ResolutionWidth + 71), SUM(ResolutionWidth + 72), SUM(ResolutionWidth + 73), SUM(ResolutionWidth + 74), SUM(ResolutionWidth + 75), SUM(ResolutionWidth + 76), SUM(ResolutionWidth + 77), SUM(ResolutionWidth + 78), SUM(ResolutionWidth + 79), SUM(ResolutionWidth + 80), SUM(ResolutionWidth + 81), SUM(ResolutionWidth + 82), SUM(ResolutionWidth + 83), SUM(ResolutionWidth + 84), SUM(ResolutionWidth + 85), SUM(ResolutionWidth + 86), SUM(ResolutionWidth + 87), SUM(ResolutionWidth + 88), SUM(ResolutionWidth + 89) FROM hits; | 0.379602 | 0.330802 | 0.262869 |
| SELECT SearchEngineID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, ClientIP ORDER BY c DESC LIMIT 10; | 1.40558 | 0.859424 | 0.890431 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 1.74251 | 0.954006 | 0.9502 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 2.48854 | 1.98602 | 2.03579 |
| SELECT URL, COUNT(*) AS c FROM hits GROUP BY URL ORDER BY c DESC LIMIT 10; | 3.20693 | 2.7416 | 2.70493 |
| SELECT 1, URL, COUNT(*) AS c FROM hits GROUP BY 1, URL ORDER BY c DESC LIMIT 10; | 3.07474 | 2.80135 | 2.76179 |
| SELECT ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3, COUNT(*) AS c FROM hits GROUP BY ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3 ORDER BY c DESC LIMIT 10; | 0.935941 | 0.748277 | 0.737648 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND URL <> '' GROUP BY URL ORDER BY PageViews DESC LIMIT 10; | 0.603558 | 0.485593 | 0.537279 |
| SELECT Title, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND Title <> '' GROUP BY Title ORDER BY PageViews DESC LIMIT 10; | 0.588045 | 0.430404 | 0.479126 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND IsLink <> 0 AND IsDownload = 0 GROUP BY URL ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 0.394164 | 0.318973 | 0.278479 |
| SELECT TraficSourceID, SearchEngineID, AdvEngineID, CASE WHEN (SearchEngineID = 0 AND AdvEngineID = 0) THEN Referer ELSE '' END AS Src, URL AS Dst, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 GROUP BY TraficSourceID, SearchEngineID, AdvEngineID, Src, Dst ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 0.809282 | 0.679725 | 0.673737 |
| SELECT URLHash, EventDate, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND TraficSourceID IN (-1, 6) AND RefererHash = 3594120000172545465 GROUP BY URLHash, EventDate ORDER BY PageViews DESC LIMIT 10 OFFSET 100; | 0.344358 | 0.258179 | 0.251927 |
| SELECT WindowClientWidth, WindowClientHeight, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND DontCountHits = 0 AND URLHash = 2868770270353813622 GROUP BY WindowClientWidth, WindowClientHeight ORDER BY PageViews DESC LIMIT 10 OFFSET 10000; | 0.402802 | 0.253936 | 0.243834 |
| SELECT DATE_TRUNC('minute', EventTime) AS M, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-14' AND EventDate <= '2013-07-15' AND IsRefresh = 0 AND DontCountHits = 0 GROUP BY DATE_TRUNC('minute', EventTime) ORDER BY DATE_TRUNC('minute', EventTime) LIMIT 10 OFFSET 1000; | 0.646189 | 0.590641 | 0.577429 |


---
This benchmark demonstrates pg_duckdb's potential to transform PostgreSQL into a high-performance analytical database platform. 🚀

Key Takeaways:
- Direct Parquet file querying
- Seamless DuckDB integration
- Vectorized query execution
- Efficient storage management
- Enhanced analytical query capabilities
