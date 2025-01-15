import duckdb
import time

def create_duckdb():
    duckdb.sql("""
        SELECT station,
            MIN(temperature) AS min_temperature,
            CAST(AVG(temperature) AS DECIMAL(3,1)) AS mean_temperature,
            MAX(temperature) AS max_temperature
        FROM read_parquet('data/medicoes_1000000000.parquet/*.parquet')
        GROUP BY station
        ORDER BY station
    """).show()

if __name__ == "__main__":
    start_time = time.time()
    create_duckdb()
    took = time.time() - start_time
    print(f"DuckDB Took: {took:.2f} sec")
