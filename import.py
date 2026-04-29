import os
import glob
import pandas as pd
from sqlalchemy import create_engine


# Database connection parameters
username = "postgres"
password = "0000"
db_name = "dendro_db"

# Create a connection to the PostgreSQL database.
# SQLAlchemy is used as an interface between Python and PostgreSQL.
engine = create_engine(
    f"postgresql+psycopg2://{username}:{password}@localhost:5432/{db_name}"
)


# IMPORT DENDROMETER METADATA
def import_dendro_metadata():

    # Read dendrometer metadata from a CSV file
    dendro = pd.read_csv(r"c:\Users\user\OneDrive\Počítač\bp\databáza\data\dendro_meta.csv", delim_whitespace=True, decimal=",")
    
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

    # Append records to the dendro_meta table.
    table_name = "dendro_meta"
    dendro.to_sql(table_name, engine, if_exists="append", index=False)
    print("Import dendro_meta completed")

def import_meteo_metadata():

    # Read meteorological metadata from a CSV file
    meteo = pd.read_csv(r"c:\Users\user\OneDrive\Počítač\bp\databáza\data\meteo_meta.csv", delim_whitespace=True, decimal=",")

    # Rename columns to match the structure of the database table.
    meteo = meteo.rename(columns={
    "ID": "meteo_id",
    "Belt": "belt",
    "Plot": "plot",
    "Date_of_instalation": "date_of_installation",
    "X": "x",
    "Y": "y",
    })

    meteo = meteo[["meteo_id", "belt", "plot", "date_of_installation", "x", "y"]]

    # Append records to the meteo_meta table.
    table_name = "meteo_meta"
    meteo.to_sql(table_name, engine, if_exists="append", index=False)
    print("Import meteo_meta completed")


# IMPORT CLEANED DENDROMETER DATA
def import_dendro_clean():
    
    # Import files from the low elevation belt.
    # The dendrometer ID is extracted from the first two characters of the file name.
    files = glob.glob(r"c:\Users\user\OneDrive\Počítač\bp\databáza\data\dendro_clean_l\*.txt")
    for file in files:
        print(f"Reading LOW file: {file}")
        try:
            name = os.path.basename(file)
            dendro_id = str(int(name[:2]))
            
            # Read cleaned dendrometer time series.
            df = pd.read_csv(file, sep="\t")
            df = df.rename(columns={"GRO": "gro"})

            # Add dendrometer ID as a foreign key
            df["dendro_id"] = dendro_id

            # Remove duplicate timestamps if present.
            df = df.drop_duplicates(subset=["ts"])

            # Append data to the dendro_data table.
            df.to_sql("dendro_data", engine, if_exists="append", index=False)

            print(f"Imported: {name}")

        except Exception as e:
            print(f"ERROR in file: {file}")
            print(repr(e))
            raise

    # Import files from the middle and high elevation belts.
    # In these files, the dendrometer ID is located at a different position in the file name.
    files = glob.glob(r"c:\Users\user\OneDrive\Počítač\bp\databáza\data\dendro_clean_mh\*.txt")
    for file in files:
        print(f"Reading MH file: {file}")
        try:
            name = os.path.basename(file)
            dendro_id = name[6:8]

            df = pd.read_csv(file, sep="\t")
            df = df.rename(columns={"GRO": "gro"})

            # Add dendrometer ID as a foreign key
            df["dendro_id"] = dendro_id

            # Remove duplicate timestamps if present.
            df = df.drop_duplicates(subset=["ts"])

            # Append data to the dendro_data table.
            df.to_sql("dendro_data", engine, if_exists="append", index=False)

            print(f"Imported: {name}")

        except Exception as e:
            print(f"ERROR in file: {file}")
            print(repr(e))
            raise

    print("Import dendro_data completed")


# IMPORT PROCESSED METEOROLOGICAL DATA
def import_meteo():

    files = glob.glob(r"C:\Users\user\OneDrive\Počítač\bp\databáza\data\meteo_processed\*.txt")

    for file in files:
        try:

            # Use the file name without extension as the meteorological station ID.
            name = os.path.basename(file)[:-4]
            meteo_id = name

            df = pd.read_csv(file, sep=",", encoding="latin1")
            df = df.rename(columns={"Time": "ts"})

            # Convert columns to appropriate data types.
            # Invalid values are converted to NaN.
            df["ts"] = pd.to_datetime(df["ts"], errors="coerce")
            df["temp"] = pd.to_numeric(df["temp"], errors="coerce")
            df["humidity"] = pd.to_numeric(df["humidity"], errors="coerce")
            df["dew_point"] = pd.to_numeric(df["dew_point"], errors="coerce")
            df["vpd"] = pd.to_numeric(df["vpd"], errors="coerce")

            print("Importing:", file)
            print(df.isna().sum())

            # Add meteorological station ID as a foreign key.
            df["meteo_id"] = meteo_id
            df = df[["meteo_id", "ts", "temp", "humidity", "dew_point", "vpd"]]

            df.to_sql("meteo_data", engine, if_exists="append", index=False)

        except Exception as e:
            print("ERROR in file:", file)
            print(e)
            break

    print("Import meteo_data completed")


# SCRIPT EXECUTION
if __name__ == "__main__":

    # Run individual import steps in the required order.
    import_dendro_metadata()
    import_meteo_metadata()
    import_dendro_clean()
    import_meteo()

    engine.dispose()
    print("Import completed")
