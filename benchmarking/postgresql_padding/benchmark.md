# Benchmarking Untuned PostgreSQL with Column Padding Optimazation for an OLAP Use Case


## **Methodology**

We used **ClickBench PostgreSQL** ([GitHub](https://github.com/ClickHouse/ClickBench/tree/main/postgresql)) for benchmarking.
ClickBench provides **43 queries** that test PostgreSQL’s performance on:

- **Aggregations**
- **Text search**
- **Other OLAP-related queries**

However, we added these optimizations on this test

- Optimized `create.sql`:
    The create.sql file has been optimized using [column padding alignment](https://stackoverflow.com/a/7431468) to improve table structure and ensure better data insertion performance.
- Updated `COPY` Command in `benchmark.sh`:
The COPY command in benchmark.sh now explicitly maps columns from the dataset to ensure proper alignment during data insertion.

## **Benchmark Machine Specifications**

The entire benchmark was run on a virtual machine with the following specifications:

| Component  | Specification  |
|------------|---------------|
| **CPU**    | 16 vCPUs      |
| **Memory** | 32 GB         |
| **Storage**| 500 GB        |

Since the data is present locally, networking details are omitted.

## **Results**

### **Table Size**

For **100 million rows**, PostgreSQL requires **67GB** of storage.

```sh
sudo du -hcs /var/lib/postgresql/14/main/
64G        /var/lib/postgresql/14/main/
64G        total
```

### **Insertion Time**

Without any parallel insertion, inserting the dataset takes **28 minutes**.

```
0.87 user 
73.92 system 
28:05.97 elapsed
```

### **Indexing**

- **Indexing time:** `0s` (No indexing applied)
- **Index Size:** `0GB` (No indexes created)

### **Query Performance**
| Query | Run 1 (seconds) | Run 2 (seconds) | Run 3 (seconds) |
|-------|----------------|----------------|----------------|
| SELECT COUNT(*) FROM hits; | 46.5154 | 47.1754 | 45.4788 |
| SELECT COUNT(*) FROM hits WHERE AdvEngineID <> 0; | 46.8312 | 46.7171 | 45.4599 |
| SELECT SUM(AdvEngineID), COUNT(*), AVG(ResolutionWidth) FROM hits; | 47.0637 | 47.7758 | 45.8714 |
| SELECT AVG(UserID) FROM hits; | 46.607 | 47.5207 | 45.2006 |
| SELECT COUNT(DISTINCT UserID) FROM hits; | 103.995 | 103.274 | 102.918 |
| SELECT COUNT(DISTINCT SearchPhrase) FROM hits; | 136.032 | 139.856 | 137.863 |
| SELECT MIN(EventDate), MAX(EventDate) FROM hits; | 46.2323 | 46.5214 | 44.9376 |
| SELECT AdvEngineID, COUNT(*) FROM hits WHERE AdvEngineID <> 0 GROUP BY AdvEngineID ORDER BY COUNT(*) DESC; | 46.4615 | 46.6137 | 45.2958 |
| SELECT RegionID, COUNT(DISTINCT UserID) AS u FROM hits GROUP BY RegionID ORDER BY u DESC LIMIT 10; | 97.8001 | 97.581 | 97.3585 |
| SELECT RegionID, SUM(AdvEngineID), COUNT(*) AS c, AVG(ResolutionWidth), COUNT(DISTINCT UserID) FROM hits GROUP BY RegionID ORDER BY c DESC LIMIT 10; | 98.05 | 96.7877 | 96.7357 |
| SELECT MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhoneModel ORDER BY u DESC LIMIT 10; | 49.6698 | 49.791 | 48.7512 |
| SELECT MobilePhone, MobilePhoneModel, COUNT(DISTINCT UserID) AS u FROM hits WHERE MobilePhoneModel <> '' GROUP BY MobilePhone, MobilePhoneModel ORDER BY u DESC LIMIT 10; | 50.4388 | 49.6125 | 48.7598 |
| SELECT SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 65.2996 | 66.0828 | 64.1097 |
| SELECT SearchPhrase, COUNT(DISTINCT UserID) AS u FROM hits WHERE SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY u DESC LIMIT 10; | 62.1171 | 61.4524 | 61.3986 |
| SELECT SearchEngineID, SearchPhrase, COUNT(*) AS c FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, SearchPhrase ORDER BY c DESC LIMIT 10; | 68.5149 | 69.2525 | 69.0107 |
| SELECT UserID, COUNT(*) FROM hits GROUP BY UserID ORDER BY COUNT(*) DESC LIMIT 10; | 116.066 | 116.3 | 116.826 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 80.0765 | 81.7216 | 80.7379 |
| SELECT UserID, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, SearchPhrase LIMIT 10; | 61.4409 | 60.4957 | 59.5296 |
| SELECT UserID, extract(minute FROM EventTime) AS m, SearchPhrase, COUNT(*) FROM hits GROUP BY UserID, m, SearchPhrase ORDER BY COUNT(*) DESC LIMIT 10; | 154.143 | 119.967 | 114.029 |
| SELECT UserID FROM hits WHERE UserID = 435090932899640449; | 46.9815 | 47.6284 | 45.5738 |
| SELECT COUNT(*) FROM hits WHERE URL LIKE '%google%'; | 49.6906 | 50.4143 | 48.842 |
| SELECT SearchPhrase, MIN(URL), COUNT(*) AS c FROM hits WHERE URL LIKE '%google%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 49.9607 | 51.8837 | 48.9725 |
| SELECT SearchPhrase, MIN(URL), MIN(Title), COUNT(*) AS c, COUNT(DISTINCT UserID) FROM hits WHERE Title LIKE '%Google%' AND URL NOT LIKE '%.google.%' AND SearchPhrase <> '' GROUP BY SearchPhrase ORDER BY c DESC LIMIT 10; | 49.7467 | 48.5607 | 49.199 |
| SELECT * FROM hits WHERE URL LIKE '%google%' ORDER BY EventTime LIMIT 10; | 49.4625 | 50.1919 | 48.7275 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime LIMIT 10; | 47.2863 | 46.7105 | 46.4995 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY SearchPhrase LIMIT 10; | 47.328 | 48.0865 | 47.52 |
| SELECT SearchPhrase FROM hits WHERE SearchPhrase <> '' ORDER BY EventTime, SearchPhrase LIMIT 10; | 50.5518 | 47.0757 | 46.5563 |
| SELECT CounterID, AVG(length(URL)) AS l, COUNT(*) AS c FROM hits WHERE URL <> '' GROUP BY CounterID HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 51.3389 | 52.4479 | 51.501 |
| SELECT REGEXP_REPLACE(Referer, '^https?://(?:www\.)?([^/]+)/.*$', '\1') AS k, AVG(length(Referer)) AS l, COUNT(*) AS c, MIN(Referer) FROM hits WHERE Referer <> '' GROUP BY k HAVING COUNT(*) > 100000 ORDER BY l DESC LIMIT 25; | 244.089 | 242.689 | 242.413 |
| SELECT SUM(ResolutionWidth), SUM(ResolutionWidth + 1), SUM(ResolutionWidth + 2), SUM(ResolutionWidth + 3), SUM(ResolutionWidth + 4), SUM(ResolutionWidth + 5), SUM(ResolutionWidth + 6), SUM(ResolutionWidth + 7), SUM(ResolutionWidth + 8), SUM(ResolutionWidth + 9), SUM(ResolutionWidth + 10), SUM(ResolutionWidth + 11), SUM(ResolutionWidth + 12), SUM(ResolutionWidth + 13), SUM(ResolutionWidth + 14), SUM(ResolutionWidth + 15), SUM(ResolutionWidth + 16), SUM(ResolutionWidth + 17), SUM(ResolutionWidth + 18), SUM(ResolutionWidth + 19), SUM(ResolutionWidth + 20), SUM(ResolutionWidth + 21), SUM(ResolutionWidth + 22), SUM(ResolutionWidth + 23), SUM(ResolutionWidth + 24), SUM(ResolutionWidth + 25), SUM(ResolutionWidth + 26), SUM(ResolutionWidth + 27), SUM(ResolutionWidth + 28), SUM(ResolutionWidth + 29), SUM(ResolutionWidth + 30), SUM(ResolutionWidth + 31), SUM(ResolutionWidth + 32), SUM(ResolutionWidth + 33), SUM(ResolutionWidth + 34), SUM(ResolutionWidth + 35), SUM(ResolutionWidth + 36), SUM(ResolutionWidth + 37), SUM(ResolutionWidth + 38), SUM(ResolutionWidth + 39), SUM(ResolutionWidth + 40), SUM(ResolutionWidth + 41), SUM(ResolutionWidth + 42), SUM(ResolutionWidth + 43), SUM(ResolutionWidth + 44), SUM(ResolutionWidth + 45), SUM(ResolutionWidth + 46), SUM(ResolutionWidth + 47), SUM(ResolutionWidth + 48), SUM(ResolutionWidth + 49), SUM(ResolutionWidth + 50), SUM(ResolutionWidth + 51), SUM(ResolutionWidth + 52), SUM(ResolutionWidth + 53), SUM(ResolutionWidth + 54), SUM(ResolutionWidth + 55), SUM(ResolutionWidth + 56), SUM(ResolutionWidth + 57), SUM(ResolutionWidth + 58), SUM(ResolutionWidth + 59), SUM(ResolutionWidth + 60), SUM(ResolutionWidth + 61), SUM(ResolutionWidth + 62), SUM(ResolutionWidth + 63), SUM(ResolutionWidth + 64), SUM(ResolutionWidth + 65), SUM(ResolutionWidth + 66), SUM(ResolutionWidth + 67), SUM(ResolutionWidth + 68), SUM(ResolutionWidth + 69), SUM(ResolutionWidth + 70), SUM(ResolutionWidth + 71), SUM(ResolutionWidth + 72), SUM(ResolutionWidth + 73), SUM(ResolutionWidth + 74), SUM(ResolutionWidth + 75), SUM(ResolutionWidth + 76), SUM(ResolutionWidth + 77), SUM(ResolutionWidth + 78), SUM(ResolutionWidth + 79), SUM(ResolutionWidth + 80), SUM(ResolutionWidth + 81), SUM(ResolutionWidth + 82), SUM(ResolutionWidth + 83), SUM(ResolutionWidth + 84), SUM(ResolutionWidth + 85), SUM(ResolutionWidth + 86), SUM(ResolutionWidth + 87), SUM(ResolutionWidth + 88), SUM(ResolutionWidth + 89) FROM hits; | 52.8142 | 54.0993 | 52.5517 |
| SELECT SearchEngineID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY SearchEngineID, ClientIP ORDER BY c DESC LIMIT 10; | 60.5792 | 60.2799 | 61.5136 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits WHERE SearchPhrase <> '' GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 62.752 | 61.942 | 61.5655 |
| SELECT WatchID, ClientIP, COUNT(*) AS c, SUM(IsRefresh), AVG(ResolutionWidth) FROM hits GROUP BY WatchID, ClientIP ORDER BY c DESC LIMIT 10; | 373.541 | 372.869 | 374.583 |
| SELECT URL, COUNT(*) AS c FROM hits GROUP BY URL ORDER BY c DESC LIMIT 10; | 204.282 | 226.491 | 204.54 |
| SELECT 1, URL, COUNT(*) AS c FROM hits GROUP BY 1, URL ORDER BY c DESC LIMIT 10; | 145.74 | 141.836 | 143.22 |
| SELECT ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3, COUNT(*) AS c FROM hits GROUP BY ClientIP, ClientIP - 1, ClientIP - 2, ClientIP - 3 ORDER BY c DESC LIMIT 10; | 68.6402 | 67.8555 | 67.5006 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND URL <> '' GROUP BY URL ORDER BY PageViews DESC LIMIT 10; | 47.4701 | 47.819 | 46.2842 |
| SELECT Title, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND DontCountHits = 0 AND IsRefresh = 0 AND Title <> '' GROUP BY Title ORDER BY PageViews DESC LIMIT 10; | 46.9056 | 47.8203 | 46.1098 |
| SELECT URL, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND IsLink <> 0 AND IsDownload = 0 GROUP BY URL ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 46.3025 | 45.7802 | 45.3401 |
| SELECT TraficSourceID, SearchEngineID, AdvEngineID, CASE WHEN (SearchEngineID = 0 AND AdvEngineID = 0) THEN Referer ELSE '' END AS Src, URL AS Dst, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 GROUP BY TraficSourceID, SearchEngineID, AdvEngineID, Src, Dst ORDER BY PageViews DESC LIMIT 10 OFFSET 1000; | 47.6211 | 46.3557 | 46.2207 |
| SELECT URLHash, EventDate, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND TraficSourceID IN (-1, 6) AND RefererHash = 3594120000172545465 GROUP BY URLHash, EventDate ORDER BY PageViews DESC LIMIT 10 OFFSET 100; | 46.4526 | 47.2732 | 45.5701 |
| SELECT WindowClientWidth, WindowClientHeight, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-01' AND EventDate <= '2013-07-31' AND IsRefresh = 0 AND DontCountHits = 0 AND URLHash = 2868770270353813622 GROUP BY WindowClientWidth, WindowClientHeight ORDER BY PageViews DESC LIMIT 10 OFFSET 10000; | 46.6596 | 47.2512 | 45.458 |
| SELECT DATE_TRUNC('minute', EventTime) AS M, COUNT(*) AS PageViews FROM hits WHERE CounterID = 62 AND EventDate >= '2013-07-14' AND EventDate <= '2013-07-15' AND IsRefresh = 0 AND DontCountHits = 0 GROUP BY DATE_TRUNC('minute', EventTime) ORDER BY DATE_TRUNC('minute', EventTime) LIMIT 10 OFFSET 1000; | 46.2328 | 47.2265 | 45.9607 |


---
This benchmark serves as a **starting point** for optimizing PostgreSQL to handle analytical queries more efficiently. 🚀
