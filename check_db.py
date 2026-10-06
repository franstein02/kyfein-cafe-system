import pymysql
try:
    conn = pymysql.connect(host='localhost', user='root', password='')
    cursor = conn.cursor()
    cursor.execute("SHOW DATABASES LIKE 'db_kyfein'")
    if cursor.fetchone():
        print("Database 'db_kyfein' exists.")
        cursor.execute("USE db_kyfein")
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        print(f"Found {len(tables)} tables.")
    else:
        print("Database 'db_kyfein' does NOT exist.")
except Exception as e:
    print(f"Error: {e}")
