#!/bin/bash
set -euo pipefail

# Optional: Uncomment if GAM not in PATH
# export PATH="$HOME/bin/gamadv-xtd3:$PATH"

# Read sensitive values from environment (provided by Jenkins)
: "${SHARED_DRIVE_ID:?Need SHARED_DRIVE_ID}"
: "${TARGET_FOLDER_ID:?Need TARGET_FOLDER_ID}"
: "${UPLOAD_USER:?Need UPLOAD_USER}"

# Filenames
TEAM_DRIVE_ACLS="TeamDriveACLs.csv"
GROUP_MEMBERS="GroupMembers.csv"
EXPANDED_ACLS="TeamDriveACLsExpandedGroups.csv"
TEAM_DRIVES="TeamDrives.csv"
ALL_TEAM_DRIVES="AllTeamDrives.csv"
TEAM_DRIVE_ORGANIZERS="TeamDriveOrganizers.csv"
TEAM_DRIVE_FILE_COUNTS_SIZE="TeamDriveFileCountsSize.csv"
TEAM_DRIVE_STORAGE_INFO="TeamDriveStorageInfo.csv"
TEAM_DRIVE_FILE_LIST="TeamDriveFileList.csv"
TEAM_DRIVE_LAST_MODIFIED="TeamDriveLastModified.csv"
ACST_SHARED_DRIVES="ACST-Current Shared Drives.csv"
ACST_SHARED_DRIVES_PROGRESS_CSV="ACST-Current Shared Drives In Progress.csv"
SHARED_DRIVES_LIST="SharedDrives.csv"
SHARED_DRIVES_ACTIVITY="SharedDrivesActivity.csv"
SHARED_DRIVE_ACLS="SharedDriveACLs.csv"

# Current date
today=$(date +%F)

# Preconditions
command -v gam >/dev/null 2>&1 || { echo "Error: gam CLI not found" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found" >&2; exit 1; }

# 1) Fetch Shared Drives list
echo "⏳ Fetching Shared Drives list..."
gam redirect csv "${SHARED_DRIVES_LIST}" print shareddrives fields id,name

# 2) Fetch Shared Drives activity (last 30 days)
echo "⏳ Fetching activity for past 30 days..."
gam redirect csv "${SHARED_DRIVES_ACTIVITY}" \
  multiprocess redirect stderr - \
  multiprocess csv "${SHARED_DRIVES_LIST}" \
    gam report drive start -30d end today \
      filter "shared_drive_id==~~id~~" \
      addcsvdata shared_drive_id "~~id~~" \
      addcsvdata shared_drive_name "~~name~~"

# Upload activity sheet
echo "⏳ Uploading activity sheet..."
gam user "${UPLOAD_USER}" add drivefile localfile "${SHARED_DRIVES_ACTIVITY}" \
  drivefilename "${SHARED_DRIVES_ACTIVITY%.csv}" \
  convert mimetype "application/vnd.google-apps.spreadsheet" \
  parentid "${TARGET_FOLDER_ID}"

# 3) Fetch per-user activity
echo "⏳ Fetching per-user activity for drive ${SHARED_DRIVE_ID}..."
csv_file="driveactivity_${SHARED_DRIVE_ID}_${today}.csv"
gam report drive user all start -30d end today \
  filter "shared_drive_id==${SHARED_DRIVE_ID}" > "${csv_file}"

# Upload per-user report
echo "⏳ Uploading per-user report..."
gam user "${UPLOAD_USER}" add drivefile localfile "${csv_file}" \
  drivefilename "${csv_file%.csv}" \
  convert mimetype "application/vnd.google-apps.spreadsheet" \
  parentid "${TARGET_FOLDER_ID}"

# 4) Fetch Shared-Drive ACLs
echo "⏳ Fetching Shared-Drive ACLs..."
gam redirect csv "${TEAM_DRIVE_ACLS}" print teamdriveacls \
  fields id,domain,emailaddress,role,type,deleted oneitemperrow

# 5) Fetch group members
echo "⏳ Fetching group members..."
gam redirect csv "${GROUP_MEMBERS}" print groups \
  roles members,managers,owners delimiter " "

# 6) Expand group ACLs
echo "⏳ Expanding group ACLs..."
python3 GetTeamDriveACLsExpandGroups.py "${TEAM_DRIVE_ACLS}" "${GROUP_MEMBERS}" "${EXPANDED_ACLS}"

# 7) Fetch Team Drives list
echo "⏳ Fetching Team Drives list..."
gam redirect csv "${TEAM_DRIVES}" print teamdrives fields id,name

# 8) Fetch all Team Drives with organizers
echo "⏳ Fetching drives with organizers..."
gam redirect csv "${ALL_TEAM_DRIVES}" print teamdrives role organizer fields id,name

# 9) Remove duplicates
echo "⏳ Removing duplicates..."
python3 DeleteDuplicateRows.py "${ALL_TEAM_DRIVES}" "${TEAM_DRIVES}"

# 10) File ACLs per drive
echo "⏳ Fetching file ACLs per drive..."
gam redirect csv "${SHARED_DRIVE_ACLS}" multiprocess csv "${TEAM_DRIVES}" \
  gam print drivefileacls "~id" fields emailaddress,role,type

# 11) Identify organizers
echo "⏳ Identifying organizers..."
python3 GetTeamDriveOrganizers.py "${SHARED_DRIVE_ACLS}" "${TEAM_DRIVES}" "${TEAM_DRIVE_ORGANIZERS}"

# 12) File counts & sizes
echo "⏳ Fetching file counts & sizes..."
gam config csv_input_row_filter "organizers:regex:^.+$" \
  redirect csv "${TEAM_DRIVE_FILE_COUNTS_SIZE}" \
  multiprocess csv "${TEAM_DRIVE_ORGANIZERS}" gam user "~organizers" \
    print filecounts select teamdriveid "~id" showsize

# 13) Generate storage info
echo "⏳ Generating storage info..."
python3 GetTeamDriveStorageInfo.py "${TEAM_DRIVE_FILE_COUNTS_SIZE}" "${TEAM_DRIVE_STORAGE_INFO}"

# 14) Last-modified per drive
echo "⏳ Fetching last-modified records..."
gam config csv_input_row_filter "organizers:regex:^.+$" \
  redirect csv "${TEAM_DRIVE_FILE_LIST}" \
  multiprocess csv "${TEAM_DRIVE_ORGANIZERS}" gam user "~organizers" \
    print filelist select teamdriveid "~id" \
    query "mimeType!='application/vnd.google-apps.folder'" \
    fields teamDriveId,id,name,modifiedtime \
    orderby modifiedtime descending maxfiles 1

# 15) Generate last-modified report
echo "⏳ Generating last-modified report..."
python3 GetTeamDriveLastModified.py "${TEAM_DRIVE_FILE_LIST}" "${TEAM_DRIVES}" "${TEAM_DRIVE_LAST_MODIFIED}"

# 16) Normalize headers
echo "⏳ Normalizing CSV headers..."
python3 modify_csv_headers.py

# 17) Merge into 'In Progress'
echo "⏳ Merging into 'In Progress' report..."
python3 merge_csv_files.py "${ACST_SHARED_DRIVES}" "${TEAM_DRIVE_STORAGE_INFO}" "${TEAM_DRIVE_LAST_MODIFIED}" "${ACST_SHARED_DRIVES_PROGRESS_CSV}"

# 18) Upload final report
echo "⏳ Uploading final merged report..."
gam user "${UPLOAD_USER}" add drivefile localfile "${ACST_SHARED_DRIVES_PROGRESS_CSV}" \
  drivefilename "${ACST_SHARED_DRIVES_PROGRESS_CSV%.csv}" \
  convert mimetype "application/vnd.google-apps.spreadsheet" parentid "${TARGET_FOLDER_ID}"

# Done
echo "✅ All tasks complete!"
