import os
import glob
import pandas as pd
from sqlalchemy import create_engine


username = "postgres"
password = "0000"
db_name = "dendro_db"

# Pripojenie na PostgreSQL
engine = create_engine(
    f"postgresql+psycopg2://{username}:{password}@localhost:5433/{db_name}"
)


# IMPORT METADÁT
def import_dendro_metadata():

    dendro = pd.read_csv("data/dendro_meta.csv", delim_whitespace=True, decimal=",")
    
    dendro = dendro.rename(columns={
    "ID": "dendro_id",
    "Belt": "belt",
    "Plot": "plot",
    "Species": "species",
    "DBH_cm": "dbh_cm",
    "Size_class": "size_class",
    "Date_of_instalation": "date_of_installation",
    "X": "x",
    "Y": "y",
    })

    dendro = dendro[["dendro_id", "belt", "plot", "species",
          "dbh_cm", "size_class", "date_of_installation", "x", "y"]]

    table_name = "dendro_meta"
    dendro.to_sql(table_name, engine, if_exists="append", index=False)
    print("Import dendro_meta completed")

def import_meteo_metadata():
    
    meteo = pd.read_csv("data/meteo_meta.csv", delim_whitespace=True, decimal=",")
    
    meteo = meteo.rename(columns={
    "ID": "meteo_id",
    "Belt": "belt",
    "Plot": "plot",
    "Date_of_instalation": "date_of_installation",
    "X": "x",
    "Y": "y",
    })

    meteo = meteo[["meteo_id", "belt", "plot", "date_of_installation", "x", "y"]]

    table_name = "meteo_meta"
    meteo.to_sql(table_name, engine, if_exists="append", index=False)
    print("Import meteo_meta completed")


# 2 DENDRO CLEAN IMPORT
def import_dendro_clean():

    # Low belt
    files = glob.glob("data/dendro_clean_l/*.txt")
    for file in files:
        name = os.path.basename(file) 
        dendro_id = name[:2]                    # prvé 2 znaky
        dendro_id = str(int(dendro_id))                 

        df = pd.read_csv(file, sep="\t")
        df["dendro_id"] = dendro_id
        df.to_sql("dendro_data", engine, if_exists="append", index=False)

    # Middle and High belt
    files = glob.glob("data/dendro_clean_mh/*.txt")
    for file in files:
        name = os.path.basename(file)
        dendro_id = name[6:8]                # 7. a 8. znak

        df = pd.read_csv(file, sep="\t")
        df["dendro_id"] = dendro_id
        df.to_sql("dendro_data", engine, if_exists="append", index=False)

    print("Import dendro_data completed")


# 2 METEO IMPORT
def import_meteo():

    files = glob.glob("data/meteo_spojene/*.txt") 
    for file in files:
        name = os.path.basename(file)[:-4]   
        meteo_id = name                  

        df = pd.read_csv(file, sep=",", encoding="latin1")
        df = df.rename(columns={
            "Time": "ts",
            "Celsius(°C)": "temp",
            "Humidity(%rh)": "humidity",
            "Dew Point(°C)": "dew_point"
        })
      
        df = df[["ts", "temp", "humidity", "dew_point"]]
        df["meteo_id"] = meteo_id
        df = df[["meteo_id", "ts", "temp", "humidity", "dew_point"]]

        df.to_sql("meteo_data", engine, if_exists="append", index=False)

    print("Import meteo_data completed")


# SPUSTENIE

if __name__ == "__main__":
    import_dendro_metadata()
    import_meteo_metadata()
    import_dendro_clean()
    import_meteo()

    engine.dispose()
    print("Import completed")
