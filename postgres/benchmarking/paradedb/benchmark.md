# Benchmarking ParadeDB for an OLAP Use Case

## **Introduction**

Benchmarking **ParadeDB**, a Postgres-native search and analytics platform, for an **OLAP (Online Analytical Processing) use case** serves as a critical performance evaluation. The goal is to demonstrate how ParadeDB enhances PostgreSQL's analytical and search capabilities by leveraging:

- Native Postgres extensions
- Full-text search capabilities
- Vectorized query processing
- Advanced analytics support
- Seamless integration with object storage

This analysis helps understand how ParadeDB transforms PostgreSQL into a high-performance analytical and search database platform.

## **Methodology**

We used **ClickBench ParadeDB** benchmark ([GitHub](https://github.com/ClickHouse/ClickBench/tree/main/paradedb)) for performance testing, utilizing a Docker-based setup for consistent and reproducible results.

### **Benchmark Environment**

- **Deployment Method:** Docker container
- **Docker Image:** `paradedb/paradedb:latest`
- **Dataset:** `hits.parquet` from ClickBench
- **Data Format:** Parquet (columnar storage format)

### **Benchmark Configuration**

The benchmark was conducted using the following key scripts:
- `benchmark.sh`: Overall benchmark orchestration
- `create-single.sql`: Table creation and data loading script
- `run.sh`: Query execution and performance measurement script

Key benchmark script components:
```sh
# Docker run command
docker run -d --name paradedb -p 5432:5432 \
    -e POSTGRES_PASSWORD=paradedb \
    -v ./hits.parquet:/tmp/hits.parquet \
    paradedb/paradedb:latest

# Dataset preparation
wget https://datasets.clickhouse.com/hits_compatible/athena/hits.parquet
```

The benchmark includes **43 queries** that test ParadeDB's performance on:
- **Complex aggregations**
- **Full-text search**
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

Storage breakdown for the ParadeDB Docker container:

```sh
# Docker container storage analysis
/tmp/hits.parquet: 14G
Total: 14G
```

### **Query Performance**
| Query | Run 1 (seconds) | Run 2 (seconds) | Run 3 (seconds) |
|-------|----------------|----------------|----------------|
| SELECT COUNT(*) FROM hits; | 0.261403 | 0.204378 | 0.196721 |
| SELECT COUNT(*) FROM hits WHERE AdvEngineID <> 0; | 0.26846 | 0.210333 | 0.213542 |
| SELECT SUM(AdvEngineID), COUNT(*), AVG(ResolutionWidth) FROM hits; | 0.347631 | 0.255072 | 0.268594 |
| SELECT AVG(UserID) FROM hits; | 0.570531 | 0.253738 | 0.241709 |
| SELECT COUNT(DISTINCT UserID) FROM hits; | 0.732185 | 0.556326 | 0.545708 |
| SELECT COUNT(DISTINCT SearchPhrase) FROM hits; | 0.975344 | 0.771194 | 0.770302 |
| SELECT MIN(EventDate), MAX(EventDate) FROM hits; | 0.270911 | 0.222603 | 0.208897 |
| SELECT AdvEngineID, COUNT(*) FROM hits WHERE AdvEngineID <> 0 GROUP BY AdvEngineID ORDER BY COUNT(*) DESC; | 0.270819 | 0.196702 | 0.219562 |
| SELECT RegionID, COUNT(DISTINCT UserID) AS u FROM hits GROUP BY RegionID ORDER BY u DESC LIMIT 10; | 0.998798 | 0.68295 | 0.761198 |
| SELECT RegionID, SUM(AdvEngineID), COUNT(*) AS c, AVG(ResolutionWidth), COUNT(DISTINCT UserID) FROM hits GROUP BY RegionID ORDER BY c DESC LIMIT 10; | 1.17858 | 0.928223 | 0.935544 |
| SELECT MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhoneModel ORDER BY u DESC LIMIT 10; | 0.587531 | 0.34345 | 0.319236 |
| SELECT MobilePhone, MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhone, MobilePhoneModel ORDER BY u DESC LIMIT 10; | 0.631233 | 0.39047 | 0.372886 |
| SELECT SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 0.90175 | 0.673149 | 0.684788 |
| SELECT SearchPhrase, COUNT(DISTINCT UserID) AS u FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY u DESC LIMIT 10; | 1.38429 | 0.998819 | 0.965711 |
| SELECT SearchEngineID, SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, SearchPhrase ORDER BY c DESC LIMIT 10; | 0.951361 | 0.749642 | 0.797683 |
| SELECT UserID, COUNT(*) FROM hits GROUP BY UserID ORDER BY COUNT(*) DESC LIMIT 10; | 0.877454 | 0.627037 | 0.660932 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 1.58197 | 1.21304 | 1.22744 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase LIMIT 10; | 1.57899 | 1.24055 | 1.2167 |
| SELECT UserID, extract(minute FROM EventTime) AS m, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, m, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 2.46176 | 1.98133 | 1.98484 |
| SELECT UserID FROM hits WHERE UserID = 435090932899640449; | 0.460442 | 0.248358 | 0.260007 |
| SELECT COUNT(*) FROM hits WHERE URL LIKE '%google%'; | 2.36041 | 1.84892 | 1.85085 |
| SELECT SearchPhrase, MIN(URL), COUNT(*) AS c FROM hits WHERE URL LIKE '%google%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 2.41387 | 1.73967 | 1.73186 |
| SELECT SearchPhrase, MIN(URL), MIN(Title), COUNT(*) AS c, COUNT(DISTINCT UserID) FROM hits WHERE Title LIKE '%Google%' AND URL NOT LIKE '%.google.%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 4.47962 | 3.58148 | 3.58954 |
| SELECT * FROM hits WHERE URL LIKE '%google%' ORDER BY EventTime LIMIT 10; | 12.4754 | 10.6377 | 10.5212 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime LIMIT 10; | 1.17934 | 0.609139 | 0.587818 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY SearchPhrase LIMIT 10; | 0.704685 | 0.507274 | 0.476245 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime, SearchPhrase LIMIT 10; | 1.07135 | 0.611662 | 0.642356 |
| SELECT CounterID, AVG(length(URL)) AS l, COUNT(*) AS c FROM hits WHERE URL <> '' GROUP BY CounterID HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 2.39779 | 1.84486 | 1.85258 |
| SELECT REGEXP_REPLACE(Referer, '^https?://(?:www\.)?([^/]+)/.*$', '\1') AS k, AVG(length(Referer)) AS l, COUNT(*) AS c, MIN(Referer) FROM hits WHERE Referer <> '' GROUP BY k HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 9.34011 | 8.75215 | 8.92183 |
| SELECT SUM(ResolutionWidth), SUM(ResolutionWidth + 1), SUM(ResolutionWidth + 2), SUM(ResolutionWidth + 3), SUM(ResolutionWidth + 4), SUM(ResolutionWidth + 5), SUM(ResolutionWidth + 6), SUM(ResolutionWidth + 7), SUM(ResolutionWidth + 8), SUM(ResolutionWidth + 9), SUM(ResolutionWidth + 10), SUM(ResolutionWidth + 11), SUM(ResolutionWidth + 12), SUM(ResolutionWidth + 13), SUM(ResolutionWidth + 14), SUM(ResolutionWidth + 15), SUM(ResolutionWidth + 16), SUM(ResolutionWidth + 17), SUM(ResolutionWidth + 18), SUM(ResolutionWidth + 19), SUM(ResolutionWidth + 20), SUM(ResolutionWidth + 21), SUM(ResolutionWidth + 22), SUM(ResolutionWidth + 23), SUM(ResolutionWidth + 24), SUM(ResolutionWidth + 25), SUM(ResolutionWidth + 26), SUM(ResolutionWidth + 27), SUM(ResolutionWidth + 28), SUM(ResolutionWidth + 29), SUM(ResolutionWidth + 30), SUM(ResolutionWidth + 31), SUM(ResolutionWidth + 32), SUM(ResolutionWidth + 33), SUM(ResolutionWidth + 34), SUM(ResolutionWidth + 35), SUM(ResolutionWidth + 36), SUM(ResolutionWidth + 37), SUM(ResolutionWidth + 38), SUM(ResolutionWidth + 39), SUM(ResolutionWidth + 40), SUM(ResolutionWidth + 41), SUM(ResolutionWidth + 42), SUM(ResolutionWidth + 43), SUM(ResolutionWidth + 44), SUM(ResolutionWidth + 45), SUM(ResolutionWidth + 46), SUM(ResolutionWidth + 47), SUM(ResolutionWidth + 48), SUM(ResolutionWidth + 49), SUM(ResolutionWidth + 50), SUM(ResolutionWidth + 51), SUM(ResolutionWidth + 52), SUM(ResolutionWidth + 53), SUM(ResolutionWidth + 54), SUM(ResolutionWidth + 55), SUM(ResolutionWidth + 56), SUM(ResolutionWidth + 57), SUM(ResolutionWidth + 58), SUM(ResolutionWidth + 59), SUM(ResolutionWidth + 60), SUM(ResolutionWidth + 61), SUM(ResolutionWidth + 62), SUM(ResolutionWidth + 63), SUM(ResolutionWidth + 64), SUM(ResolutionWidth + 65), SUM(ResolutionWidth + 66), SUM(ResolutionWidth + 67), SUM(ResolutionWidth + 68), SUM(ResolutionWidth + 69), SUM(ResolutionWidth + 70), SUM(ResolutionWidth + 71), SUM(ResolutionWidth + 72), SUM(ResolutionWidth + 73), SUM(ResolutionWidth + 74), SUM(ResolutionWidth + 75), SUM(ResolutionWidth + 76), SUM(ResolutionWidth + 77), SUM(ResolutionWidth + 78), SUM(ResolutionWidth + 79), SUM(ResolutionWidth + 80), SUM(ResolutionWidth + 81), SUM(ResolutionWidth + 82), SUM(ResolutionWidth + 83), SUM(ResolutionWidth + 84), SUM(ResolutionWidth + 85), SUM(ResolutionWidth + 86), SUM(ResolutionWidth + 87), SUM(ResolutionWidth + 88), SUM(ResolutionWidth + 89) FROM hits; | 0.79101 | 0.600498 | 0.660059 |
| SELECT SearchEngineID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, ClientIP ORDER BY c DESC LIMIT 10; | 1.26859 | 0.816854 | 0.806422 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 1.82041 | 0.969817 | 0.944868 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 2.66853 | 2.23138 | 2.43216 |
| SELECT URL, COUNT(*) AS c FROM hits GROUP BY URL ORDER BY c DESC LIMIT 10; | 2.97306 | 2.54236 | 2.65856 |
| SELECT 1, URL, COUNT(*) AS c FROM hits GROUP BY 1, URL ORDER BY c DESC LIMIT 10; | 3.02236 | 2.63013 | 2.61972 |
| SELECT ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3, COUNT(*) AS c FROM hits GROUP BY ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3 ORDER BY c DESC LIMIT 10; | 0.907835 | 0.768288 | 0.681143 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND URL <> '' GROUP BY URL ORDER BY PageViews DESC LIMIT 10; | 0.456562 | 0.383236 | 0.383455 |
| SELECT Title, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND Title <> '' GROUP BY Title ORDER BY PageViews DESC LIMIT 10; | 0.359792 | 0.303284 | 0.309524 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND IsLink <> 0 AND IsDownload = 0 GROUP BY URL ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 0.355177 | 0.29716 | 0.29792 |
| SELECT TraficSourceID, SearchEngineID, AdvEngineID, CASE WHEN (SearchEngineID = 0 AND AdvEngineID = 0) THEN Referer ELSE '' END AS Src, URL AS Dst, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 GROUP BY TraficSourceID, SearchEngineID, AdvEngineID, Src, Dst ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 0.689723 | 0.594082 | 0.558726 |
| SELECT URLHash, EventDate, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND TraficSourceID IN (-1, 6) AND RefererHash = 3594120000172545465 GROUP BY URLHash, EventDate ORDER BY PageViews DESC LIMIT 10 OFFSET 100; | 0.27518 | 0.198677 | 0.201897 |
| SELECT WindowClientWidth, WindowClientHeight, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND DontCountHits = 0 AND URLHash = 2868770270353813622 GROUP BY WindowClientWidth, WindowClientHeight ORDER BY PageViews DESC LIMIT 10 OFFSET 10000; | 0.251501 | 0.201624 | 0.202913 |
| SELECT DATE_TRUNC('minute', EventTime) AS M, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-14' AND EventDate <= '2013-07-15' AND IsRefresh = 0 AND DontCountHits = 0 GROUP BY DATE_TRUNC('minute', EventTime) ORDER BY DATE_TRUNC('minute', EventTime) LIMIT 10 OFFSET 1000; | 0.267617 | 0.227991 | 0.215066 |


---
This benchmark demonstrates ParadeDB's potential to transform PostgreSQL into a high-performance search and analytics database platform. 🚀

