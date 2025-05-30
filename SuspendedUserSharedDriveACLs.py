import pandas as pd
import sys

def filter_suspended_users_acls(shared_drive_acls_file, output_file, suspended_users_file):
    # Load CSV files into DataFrames
    shared_drive_acls_df = pd.read_csv(shared_drive_acls_file)
    suspended_users_df = pd.read_csv(suspended_users_file)

    # Extract list of suspended user email addresses
    suspended_emails = set(suspended_users_df["primaryEmail"])

    # Filter Shared Drive ACLs where emailAddress matches suspended users
    suspended_acls = shared_drive_acls_df[shared_drive_acls_df["emailAddress"].isin(suspended_emails)]

    # Save the filtered data
    suspended_acls.to_csv(output_file, index=False)

    print(f"Filtered Suspended Users' Shared Drive ACLs saved to {output_file}")

# Run the function
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python GetSuspendedUserSharedDriveACLs.py shared_drive_acls.csv output.csv suspended_users.csv")
    else:
        filter_suspended_users_acls(sys.argv[1], sys.argv[2], sys.argv[3])
