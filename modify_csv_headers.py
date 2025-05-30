import csv

def modify_csv_headers(input_file):
    """Modify headers and remove specific columns, overwriting the original file."""
    
    # Define the header changes
    header_changes = {
        "permission.domain": "domain",
        "permission.emailAddress": "EmailAddress",
        "name": "Drive Name",
        "permission.role": "Role",
        "permission.group": "group"
    }

    # Columns to remove from TeamDriveACLsExpandedGroups.csv
    remove_columns = {"User", "permission.deleted", "permission.id", "permission.type"}

    # Read the file and modify it in memory
    with open(input_file, mode='r', newline='', encoding='utf-8') as infile:
        reader = csv.DictReader(infile)
        
        new_fieldnames = [
            header_changes.get(col, col) for col in reader.fieldnames if col not in remove_columns
        ]

        rows = []
        for row in reader:
            new_row = {header_changes.get(col, col): row[col] for col in row if col not in remove_columns}
            rows.append(new_row)

    # Overwrite the original file with the modified data
    with open(input_file, mode='w', newline='', encoding='utf-8') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=new_fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"CSV headers modified and overwritten in {input_file}")


def remove_column(input_file, column_to_remove):
    """Remove a specific column from a CSV file."""
    with open(input_file, mode='r', newline='', encoding='utf-8') as infile:
        reader = csv.DictReader(infile)
        
        if column_to_remove not in reader.fieldnames:
            print(f"Column '{column_to_remove}' not found in {input_file}. Skipping modification.")
            return

        new_fieldnames = [col for col in reader.fieldnames if col != column_to_remove]

        rows = []
        for row in reader:
            del row[column_to_remove]
            rows.append(row)

    # Overwrite the file with the modified version
    with open(input_file, mode='w', newline='', encoding='utf-8') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=new_fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Column '{column_to_remove}' removed from {input_file}")


# File names
team_drive_acls_file = "TeamDriveACLsExpandedGroups.csv"
team_drive_last_modified_file = "TeamDriveLastModified.csv"

# Run functions
modify_csv_headers(team_drive_acls_file)
remove_column(team_drive_last_modified_file, "name")
