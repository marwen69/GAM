import csv

# Load TeamDrives.csv into a dictionary
drives = {}
with open('TeamDrives.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        drives[row['id']] = {'name': row['name'], 'createdTime': row['createdTime']}

# Open the ACLs CSV and normalize
with open('TeamDriveACLs.csv', 'r', encoding='utf-8') as infile, \
     open('NormalizedTeamDriveACLs.csv', 'w', newline='', encoding='utf-8') as outfile:
    
    reader = csv.DictReader(infile)
    fieldnames = ['id', 'name', 'createdTime', 'emailAddress', 'role', 'type']
    writer = csv.DictWriter(outfile, fieldnames=fieldnames)
    writer.writeheader()

    for row in reader:
        drive_id = row['id']
        name = drives.get(drive_id, {}).get('name', 'N/A')
        created_time = drives.get(drive_id, {}).get('createdTime', 'N/A')
        
        # Iterate through permissions
        i = 0
        while f'permissions.{i}.emailAddress' in row:
            email = row.get(f'permissions.{i}.emailAddress', '')
            role = row.get(f'permissions.{i}.role', '')
            type_ = row.get(f'permissions.{i}.type', '')
            
            if email:  # Only include if emailAddress exists
                writer.writerow({
                    'id': drive_id,
                    'name': name,
                    'createdTime': created_time,
                    'emailAddress': email,
                    'role': role,
                    'type': type_
                })
            i += 1
