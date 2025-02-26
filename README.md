# pg-olap-recipies
This repository contains a bunch of notes on making postgres work well for analytics workloads. For the purpose of benchmark we rely on [ClickBench](https://benchmark.clickhouse.com/). Specifically, we want to
1. Make stock postgres work better for OLAP queries.
2. Track the related extensions, foreign data wrappers and Table Access Methods and
3. Eventually make postgres (or postgres compatible databases) rank better on ClickBench.

In the true Postgres style, we intend to work with the community. We welcome contributions in this repo. Please file your requests via github issues and feel free to send PRs on the pending requests.
