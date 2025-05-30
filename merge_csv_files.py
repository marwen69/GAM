import pandas as pd

def merge_csv_files(shared_drives_file, storage_info_file, last_modified_file, organizers_file, output_file):
    # Load CSV files into DataFrames
    shared_drives_df = pd.read_csv(shared_drives_file)
    storage_info_df = pd.read_csv(storage_info_file)
    last_modified_df = pd.read_csv(last_modified_file)
    organizers_df = pd.read_csv(organizers_file)

    # Merge on 'id' (Team Drive ID)
    merged_df = (
        shared_drives_df
        .merge(storage_info_df, on='id', how='left')
        .merge(last_modified_df, on='id', how='left')
        .merge(organizers_df, on='id', how='left')
    )

    # Save merged file
    merged_df.to_csv(output_file, index=False)
    print(f"Merged CSV saved as {output_file}")

# File names
shared_drives_file = "TeamDriveACLsExpandedGroups.csv"
storage_info_file = "TeamDriveStorageInfo.csv"
last_modified_file = "TeamDriveLastModified.csv"
organizers_file = "TeamDriveOrganizers.csv"
output_file = "ACST-Current Shared Drives In Progress.csv"

# Run merge function
merge_csv_files(
    shared_drives_file,
    storage_info_file,
    last_modified_file,
    organizers_file,
    output_file
)
