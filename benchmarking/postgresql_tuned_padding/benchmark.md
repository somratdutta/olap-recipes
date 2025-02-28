# Benchmarking Untuned PostgreSQL for an OLAP Use Case

## **Methodology**

We used **ClickBench PostgreSQL** ([GitHub](https://github.com/ClickHouse/ClickBench/tree/main/postgresql-tuned)) for benchmarking.
ClickBench provides **43 queries** that test PostgreSQL’s performance on:

- **Aggregations**
- **Text search**
- **Other OLAP-related queries**

## **Benchmark Machine Specifications**

The entire benchmark was run on a virtual machine with the following specifications:

| Component  | Specification  |
|------------|---------------|
| **CPU**    | 16 vCPUs      |
| **Memory** | 32 GB         |
| **Storage**| 500 GB        |

Since the data is present locally, networking details are omitted.

## **Configuration Parameters**
This postgresql runs with the following values of postgresql parameters changed.

| Parameter                       | Old Configuration | New Configuration |
|---------------------------------|-------------------|-------------------|
| shared_buffers                  | 128MB             | 8GB               |
| max_parallel_workers            | 8                 | 16                |
| max_parallel_workers_per_gather | 2                 | 8                 |
| max_wal_size                    | 1GB               | 32GB              |

Further optimizations:

- Optimized `create.sql`:
    The create.sql file has been optimized using [column padding alignment](https://stackoverflow.com/a/7431468) to improve table structure and ensure better data insertion performance.
- Updated `COPY` Command in `benchmark.sh`:
The COPY command in benchmark.sh now explicitly maps columns from the dataset to ensure proper alignment during data insertion.

---
### 1. `shared_buffers`: 128MB → 8GB
#### What it does:
- The shared_buffers parameter in PostgreSQL controls how much memory PostgreSQL uses for caching data pages before relying on the OS file cache.

#### Expected Gains:
- **Fewer disk reads**: A larger cache means more queries can be served from memory instead of disk, improving query performance.
- **Faster query performance**: If a queried table or index is frequently accessed, keeping it in memory reduces disk I/O, speeding up read-heavy workloads. If indexes remain cached in this memory, read queries that use these indexing can be executed quicker.

---

### 2. `max_parallel_workers`: 8 → 16
#### What it does:
- Controls the maximum number of parallel workers that can be used by the database system for parallel query execution. They are not assigned to background tasks like autovacuum or replication; instead, they are specifically used for parallel query execution.

#### Expected Gains:
- **Better parallel execution for queries**: Queries that benefit from parallelism (e.g., large `JOIN`s, `AGGREGATE`s, `INDEX` scans) will see improved performance.
- **Higher CPU utilization**: More efficient use of available CPU cores, especially on multi-core machines.

---

### 3. `max_parallel_workers_per_gather`: 2 → 8

### What it does:
- Controls the maximum number of parallel workers that can be used for a single query execution plan node that involves parallel processing. This setting is closely related to max_parallel_workers, but it focuses on the granularity of parallelism at the query level.

### Expected Gains:
- **Improved query execution time**: Queries that support parallelism (e.g., `SELECT COUNT(*)`, `SUM()`, `AVG()` on large datasets) will run faster by utilizing more CPU cores.
- **More efficient multi-threaded execution**: Beneficial for analytical workloads with complex joins and aggregations.

---

## 4. `max_wal_size`: 1GB → 32GB

### What it does:
- Controls the total size of Write-Ahead Log (WAL) segments before a checkpoint is triggered. A checkpoint is a process where all dirty (modified) pages in memory are written to disk, and the WAL is truncated to free up space.

### Expected Gains:
- **Fewer checkpoints**: Increasing `max_wal_size` means PostgreSQL will write fewer checkpoints, reducing I/O overhead.
- **Faster write performance**: Especially helpful for high-write workloads, as excessive checkpoints can slow down transactions.

---

## 5. Column Padding Alighnment

### What it does:
- It optimizes the physical storage layout by reordering table columns (a technique often called `"Column Tetris"`) to minimize wasted space due to alignment padding. By placing larger fixed-length columns (e.g. 8-byte integers) before smaller ones, PostgreSQL reduces the extra bytes added for data alignment.

### Expected Gains:
- **Reduced storage footprint**: Even saving a few bytes per row can lead to gigabytes or terabytes saved over billions of rows.
- **Improved I/O performance**: With a tighter data layout, the database can read and cache rows more efficiently, potentially speeding up query performance.

---

### **Overall Expected Performance Impact**
- Increased memory utilization for caching and reduced disk I/O.
- More efficient parallel query execution, benefiting analytical workloads.
- Improved write performance with reduced checkpoint overhead.
- Enhanced system throughput for both read and write-heavy workloads.
---
## **Indexing**

- Refer [indexing queries](https://github.com/ClickHouse/ClickBench/blob/main/postgresql-tuned/index.sql) to learn more about the indexes created.

### Notes: 
- Gin indexes were created to speed up full text queries.

### **Table Size**

For **100 million rows**, PostgreSQL requires **115 Gb** of storage.

```sh
sudo du -hcs /var/lib/postgresql/14/main/
115G        /var/lib/postgresql/14/main/
115G        total
```

When querying the pg_relation_size (it doesn't include tmp files, toasted attributes wal records and indexing size) the table size came out to be **61 Gb** in size.
```shell
SELECT pg_size_pretty(pg_relation_size('hits')) AS table_size;
 table_size 
------------
 61 GB
(1 row)
```
### **Insertion Time**

With parallel insertion (refer this [script](https://github.com/ClickHouse/ClickBench/blob/main/postgresql-tuned/benchmark.sh)), inserting the dataset takes **6.873 minutes (412 seconds)**.

```
time split /tmp/hits.tsv --verbose -n r/$(( $(nproc)/2 )) --filter='sudo -u postgres psql test2 -t -c "\\copy hits (WatchID, JavaEnable, Title, GoodEvent, EventTime, EventDate, CounterID, ClientIP, RegionID, UserID, CounterClass, OS, UserAgent, URL, Referer, IsRefresh, RefererCategoryID, RefererRegionID, URLCategoryID, URLRegionID, ResolutionWidth, ResolutionHeight, ResolutionDepth, FlashMajor, FlashMinor, FlashMinor2, NetMajor, NetMinor, UserAgentMajor, UserAgentMinor, CookieEnable, JavascriptEnable, IsMobile, MobilePhone, MobilePhoneModel, Params, IPNetworkID, TraficSourceID, SearchEngineID, SearchPhrase, AdvEngineID, IsArtifical, WindowClientWidth, WindowClientHeight, ClientTimeZone, ClientEventTime, SilverlightVersion1, SilverlightVersion2, SilverlightVersion3, SilverlightVersion4, PageCharset, CodeVersion, IsLink, IsDownload, IsNotBounce, FUniqID, OriginalURL, HID, IsOldCounter, IsEvent, IsParameter, DontCountHits, WithHash, HitColor, LocalEventTime, Age, Sex, Income, Interests, Robotness, RemoteIP, WindowName, OpenerName, HistoryLength, BrowserLanguage, BrowserCountry, SocialNetwork, SocialAction, HTTPError, SendTiming, DNSTiming, ConnectTiming, ResponseStartTiming, ResponseEndTiming, FetchTiming, SocialSourceNetworkID, SocialSourcePage, ParamPrice, ParamOrderID, ParamCurrency, ParamCurrencyID, OpenstatServiceName, OpenstatCampaignID, OpenstatAdID, OpenstatSourceID, UTMSource, UTMMedium, UTMCampaign, UTMContent, UTMTerm, FromTag, HasGCLID, RefererHash, URLHash, CLID) FROM STDIN"'
executing with FILE=xaa
executing with FILE=xab
executing with FILE=xac
executing with FILE=xad
executing with FILE=xae
executing with FILE=xaf
executing with FILE=xag
executing with FILE=xah
COPY 12499688
COPY 12499687
COPY 12499687
COPY 12499687
COPY 12499687
COPY 12499687
COPY 12499687
COPY 12499687

real        6m52.399s
user        0m14.043s
sys        1m41.489s
```

### **Indexing**
#### Indexing time:
- It took `2.07 hours (7642 seconds)` to index 100 millon records
```shell
18 indexes created. Time taken as follows:
time sudo -u postgres psql test -t < ~/ClickBench/postgresql-tuned/index.sql
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE INDEX

0.00 user 
0.00 system 
2:07:22 elapsed
```

#### Index Size:
- Total index size is `36 Gb`
```shell
test=# SELECT pg_size_pretty(pg_indexes_size('hits')) AS indexes_size;
 indexes_size 
--------------
 36 GB
(1 row)

```


### **Query Performance**
| Query | Run 1 (seconds) | Run 2 (seconds) | Run 3 (seconds) |
|-------|----------------|----------------|----------------|
| SELECT COUNT(*) FROM hits; | 2.11029 | 1.03803 | 1.02128 |
| SELECT COUNT(*) FROM hits WHERE AdvEngineID <> 0; | 1.08984 | 0.935204 | 0.910609 |
| SELECT SUM(AdvEngineID), COUNT(*), AVG(ResolutionWidth) FROM hits; | 34.5931 | 34.9432 | 33.6485 |
| SELECT AVG(UserID) FROM hits; | 3.01875 | 1.90277 | 1.92518 |
| SELECT COUNT(DISTINCT UserID) FROM hits; | 37.1731 | 36.8639 | 36.6825 |
| SELECT COUNT(DISTINCT SearchPhrase) FROM hits; | 61.393 | 59.9759 | 60.3364 |
| SELECT MIN(EventDate), MAX(EventDate) FROM hits; | 0.009941 | 0.003105 | 0.00271 |
| SELECT AdvEngineID, COUNT(*) FROM hits WHERE AdvEngineID <> 0 GROUP BY AdvEngineID ORDER BY COUNT(*) DESC; | 1.14244 | 0.917009 | 0.923782 |
| SELECT RegionID, COUNT(DISTINCT UserID) AS u FROM hits GROUP BY RegionID ORDER BY u DESC LIMIT 10; | 24.3767 | 23.0735 | 23.045 |
| SELECT RegionID, SUM(AdvEngineID), COUNT(*) AS c, AVG(ResolutionWidth), COUNT(DISTINCT UserID) FROM hits GROUP BY RegionID ORDER BY c DESC LIMIT 10; | 82.1575 | 80.7828 | 80.168 |
| SELECT MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhoneModel ORDER BY u DESC LIMIT 10; | 5.81426 | 4.69773 | 4.74026 |
| SELECT MobilePhone, MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhone, MobilePhoneModel ORDER BY u DESC LIMIT 10; | 79.4995 | 70.0734 | 71.019 |
| SELECT SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 4.10717 | 3.4852 | 3.39959 |
| SELECT SearchPhrase, COUNT(DISTINCT UserID) AS u FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY u DESC LIMIT 10; | 16.9787 | 14.6365 | 14.7818 |
| SELECT SearchEngineID, SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, SearchPhrase ORDER BY c DESC LIMIT 10; | 50.8027 | 51.1397 | 49.9925 |
| SELECT UserID, COUNT(*) FROM hits GROUP BY UserID ORDER BY COUNT(*) DESC LIMIT 10; | 6.8154 | 6.39989 | 6.37866 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 22.8212 | 22.3809 | 22.2566 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase LIMIT 10; | 0.006244 | 0.003466 | 0.003259 |
| SELECT UserID, extract(minute FROM EventTime) AS m, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, m, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 85.9317 | 85.4963 | 85.9013 |
| SELECT UserID FROM hits WHERE UserID = 435090932899640449; | 0.008441 | 0.002204 | 0.003646 |
| SELECT COUNT(*) FROM hits WHERE URL LIKE '%google%'; | 8.92003 | 0.147239 | 0.145805 |
| SELECT SearchPhrase, MIN(URL), COUNT(*) AS c FROM hits WHERE URL LIKE '%google%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 0.151508 | 0.126522 | 0.137828 |
| SELECT SearchPhrase, MIN(URL), MIN(Title), COUNT(*) AS c, COUNT(DISTINCT UserID) FROM hits WHERE Title LIKE '%Google%' AND URL NOT LIKE '%.google.%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 12.1311 | 0.178523 | 0.184371 |
| SELECT * FROM hits WHERE URL LIKE '%google%' ORDER BY EventTime LIMIT 10; | 0.15645 | 0.127261 | 0.127132 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime LIMIT 10; | 0.031665 | 0.003239 | 0.002996 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY SearchPhrase LIMIT 10; | 0.00619 | 0.003008 | 0.003005 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime, SearchPhrase LIMIT 10; | 0.011158 | 0.004336 | 0.003904 |
| SELECT CounterID, AVG(length(URL)) AS l, COUNT(*) AS c FROM hits WHERE URL <> '' GROUP BY CounterID HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 39.8651 | 38.2245 | 38.215 |
| SELECT REGEXP_REPLACE(Referer, '^https?://(?:www\.)?([^/]+)/.*$', '\1') AS k, AVG(length(Referer)) AS l, COUNT(*) AS c, MIN(Referer) FROM hits WHERE Referer <> '' GROUP BY k HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 107.013 | 102.749 | 102.26 |
| SELECT SUM(ResolutionWidth), SUM(ResolutionWidth + 1), SUM(ResolutionWidth + 2), SUM(ResolutionWidth + 3), SUM(ResolutionWidth + 4), SUM(ResolutionWidth + 5), SUM(ResolutionWidth + 6), SUM(ResolutionWidth + 7), SUM(ResolutionWidth + 8), SUM(ResolutionWidth + 9), SUM(ResolutionWidth + 10), SUM(ResolutionWidth + 11), SUM(ResolutionWidth + 12), SUM(ResolutionWidth + 13), SUM(ResolutionWidth + 14), SUM(ResolutionWidth + 15), SUM(ResolutionWidth + 16), SUM(ResolutionWidth + 17), SUM(ResolutionWidth + 18), SUM(ResolutionWidth + 19), SUM(ResolutionWidth + 20), SUM(ResolutionWidth + 21), SUM(ResolutionWidth + 22), SUM(ResolutionWidth + 23), SUM(ResolutionWidth + 24), SUM(ResolutionWidth + 25), SUM(ResolutionWidth + 26), SUM(ResolutionWidth + 27), SUM(ResolutionWidth + 28), SUM(ResolutionWidth + 29), SUM(ResolutionWidth + 30), SUM(ResolutionWidth + 31), SUM(ResolutionWidth + 32), SUM(ResolutionWidth + 33), SUM(ResolutionWidth + 34), SUM(ResolutionWidth + 35), SUM(ResolutionWidth + 36), SUM(ResolutionWidth + 37), SUM(ResolutionWidth + 38), SUM(ResolutionWidth + 39), SUM(ResolutionWidth + 40), SUM(ResolutionWidth + 41), SUM(ResolutionWidth + 42), SUM(ResolutionWidth + 43), SUM(ResolutionWidth + 44), SUM(ResolutionWidth + 45), SUM(ResolutionWidth + 46), SUM(ResolutionWidth + 47), SUM(ResolutionWidth + 48), SUM(ResolutionWidth + 49), SUM(ResolutionWidth + 50), SUM(ResolutionWidth + 51), SUM(ResolutionWidth + 52), SUM(ResolutionWidth + 53), SUM(ResolutionWidth + 54), SUM(ResolutionWidth + 55), SUM(ResolutionWidth + 56), SUM(ResolutionWidth + 57), SUM(ResolutionWidth + 58), SUM(ResolutionWidth + 59), SUM(ResolutionWidth + 60), SUM(ResolutionWidth + 61), SUM(ResolutionWidth + 62), SUM(ResolutionWidth + 63), SUM(ResolutionWidth + 64), SUM(ResolutionWidth + 65), SUM(ResolutionWidth + 66), SUM(ResolutionWidth + 67), SUM(ResolutionWidth + 68), SUM(ResolutionWidth + 69), SUM(ResolutionWidth + 70), SUM(ResolutionWidth + 71), SUM(ResolutionWidth + 72), SUM(ResolutionWidth + 73), SUM(ResolutionWidth + 74), SUM(ResolutionWidth + 75), SUM(ResolutionWidth + 76), SUM(ResolutionWidth + 77), SUM(ResolutionWidth + 78), SUM(ResolutionWidth + 79), SUM(ResolutionWidth + 80), SUM(ResolutionWidth + 81), SUM(ResolutionWidth + 82), SUM(ResolutionWidth + 83), SUM(ResolutionWidth + 84), SUM(ResolutionWidth + 85), SUM(ResolutionWidth + 86), SUM(ResolutionWidth + 87), SUM(ResolutionWidth + 88), SUM(ResolutionWidth + 89) FROM hits; | 8.81505 | 8.15889 | 8.1699 |
| SELECT SearchEngineID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, ClientIP ORDER BY c DESC LIMIT 10; | 44.4578 | 44.1435 | 43.4231 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 48.2549 | 47.2847 | 47.5598 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 123.551 | 121.159 | 120.978 |
| SELECT URL, COUNT(*) AS c FROM hits GROUP BY URL ORDER BY c DESC LIMIT 10; | 114.18 | 115.158 | 113.627 |
| SELECT 1, URL, COUNT(*) AS c FROM hits GROUP BY 1, URL ORDER BY c DESC LIMIT 10; | 97.2451 | 98.357 | 98.3499 |
| SELECT ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3, COUNT(*) AS c FROM hits GROUP BY ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3 ORDER BY c DESC LIMIT 10; | 29.8664 | 26.8415 | 26.516 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND URL <> '' GROUP BY URL ORDER BY PageViews DESC LIMIT 10; | 2.20623 | 0.89412 | 0.888609 |
| SELECT Title, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND Title <> '' GROUP BY Title ORDER BY PageViews DESC LIMIT 10; | 0.746378 | 0.576024 | 0.603365 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND IsLink <> 0 AND IsDownload = 0 GROUP BY URL ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 0.544231 | 0.400685 | 0.379766 |
| SELECT TraficSourceID, SearchEngineID, AdvEngineID, CASE WHEN (SearchEngineID = 0 AND AdvEngineID = 0) THEN Referer ELSE '' END AS Src, URL AS Dst, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 GROUP BY TraficSourceID, SearchEngineID, AdvEngineID, Src, Dst ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 1.58671 | 1.4795 | 1.45806 |
| SELECT URLHash, EventDate, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND TraficSourceID IN (-1, 6) AND RefererHash = 3594120000172545465 GROUP BY URLHash, EventDate ORDER BY PageViews DESC LIMIT 10 OFFSET 100; | 0.492833 | 0.358654 | 0.367199 |
| SELECT WindowClientWidth, WindowClientHeight, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND DontCountHits = 0 AND URLHash = 2868770270353813622 GROUP BY WindowClientWidth, WindowClientHeight ORDER BY PageViews DESC LIMIT 10 OFFSET 10000; | 0.549648 | 0.379487 | 0.36621 |
| SELECT DATE_TRUNC('minute', EventTime) AS M, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-14' AND EventDate <= '2013-07-15' AND IsRefresh = 0 AND DontCountHits = 0 GROUP BY DATE_TRUNC('minute', EventTime) ORDER BY DATE_TRUNC('minute', EventTime) LIMIT 10 OFFSET 1000; | 1.20196 | 0.974144 | 0.975181 |


---
This benchmark serves as a **starting point** for optimizing PostgreSQL to handle analytical queries more efficiently. 🚀
