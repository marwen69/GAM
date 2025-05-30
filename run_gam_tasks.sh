#!/bin/bash
set -euo pipefail

# ————————————
# (Optional) If GAM isn’t on your PATH, uncomment and adjust:
# export PATH="$HOME/bin/gamadv-xtd3:$PATH"

# ————————————
# Read sensitive values from environment (injected by Jenkins)
: "${SHARED_DRIVE_ID:?Environment variable SHARED_DRIVE_ID is not set}"
: "${TARGET_FOLDER_ID:?Environment variable TARGET_FOLDER_ID is not set}"
: "${UPLOAD_USER:?Environment variable UPLOAD_USER is not set}"

# ————————————
# Filenames and Settings
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
ACST_SHARED_DRIVES_PROGRESS_XLS="ACST-Current Shared Drives In Progress.xls"
SHARED_DRIVES_LIST="SharedDrives.csv"
SHARED_DRIVES_ACTIVITY="SharedDrivesActivity.csv"
SUSPENDED_USERS="SuspendedUsers.csv"
SHARED_DRIVE_ACLS="SharedDriveACLs.csv"
SUSPENDED_SHARED_DRIVE_ACLS="SuspendedUserSharedDriveACLs.csv"

today=$(date +%F)

# ————————————
# Preconditions
command -v gam >/dev/null 2>&1 || { echo "Error: gam CLI not found in PATH" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found" >&2; exit 1; }

#————————————

# 1) Fetch Shared Drives list
echo "⏳ Fetching Shared Drives list…"
gam redirect csv ./"${SHARED_DRIVES_LIST}" print shareddrives fields id,name

# 2) Fetch Shared Drives activity (last 30 days)
echo "⏳ Fetching Shared Drives activity for the past 30 days…"
gam redirect csv ./"${SHARED_DRIVES_ACTIVITY}" \
  multiprocess redirect stderr - \
  multiprocess csv "${SHARED_DRIVES_LIST}" \
  gam report drive start -30d end today \
    filter "shared_drive_id==~~id~~" \
    addcsvdata shared_drive_id "~~id~~" \
    addcsvdata shared_drive_name "~~name~~"

# 2a) Upload Shared Drives activity sheet
echo "⏳ Uploading ${SHARED_DRIVES_ACTIVITY} to Drive folder ${TARGET_FOLDER_ID}…"
gam user "${UPLOAD_USER}" add drivefile localfile "${SHARED_DRIVES_ACTIVITY}" \
  drivefilename "${SHARED_DRIVES_ACTIVITY%.csv}" \
  convert mimetype "application/vnd.google-apps.spreadsheet" \
  parentid "${TARGET_FOLDER_ID}"

# 3) Fetch per-user activity for one Shared Drive
echo "⏳ Fetching per-user activity for drive ${SHARED_DRIVE_ID}…"
csv_file="driveactivity_${SHARED_DRIVE_ID}_${today}.csv"
gam report drive user all start -30d end today \
  filter "shared_drive_id==${SHARED_DRIVE_ID}" > "${csv_file}"

# 3a) Upload per-user activity
echo "⏳ Uploading ${csv_file} to Drive folder ${TARGET_FOLDER_ID}…"
gam user "${UPLOAD_USER}" add drivefile localfile "${csv_file}" \
  drivefilename "${csv_file%.csv}" \
  convert mimetype "application/vnd.google-apps.spreadsheet" \
  parentid "${TARGET_FOLDER_ID}"

# ————————————
# 4) Fetch Shared-Drive ACLs
echo "⏳ Fetching Shared-Drive ACLs…"
gam redirect csv ./"${TEAM_DRIVE_ACLS}" print teamdriveacls \
  fields id,domain,emailaddress,role,type,deleted oneitemperrow

# 5) Fetch group members
echo "⏳ Fetching group members…"
gam redirect csv ./"${GROUP_MEMBERS}" print groups \
  roles members,managers,owners delimiter " "

# 6) Expand group ACLs
echo "⏳ Expanding group ACLs…"
python3 GetTeamDriveACLsExpandGroups.py "${TEAM_DRIVE_ACLS}" "${GROUP_MEMBERS}" "${EXPANDED_ACLS}"

# 7) Fetch team drives list
echo "⏳ Fetching Team Drives…"
gam redirect csv ./"${TEAM_DRIVES}" print teamdrives fields id,name

# 8) Fetch all team drives with organizers
echo "⏳ Fetching all Team Drives with organizers…"
gam redirect csv ./"${ALL_TEAM_DRIVES}" print teamdrives role organizer fields id,name

# 9) Remove duplicates
echo "⏳ Removing duplicates from ${ALL_TEAM_DRIVES}…"
python3 DeleteDuplicateRows.py "${ALL_TEAM_DRIVES}" "${TEAM_DRIVES}"

# 10) File ACLs per drive
echo "⏳ Fetching file ACLs per drive…"
gam redirect csv ./"${SHARED_DRIVE_ACLS}" multiprocess csv ./"${TEAM_DRIVES}" gam print drivefileacls "~id" \
  fields emailaddress,role,type

# 11) Identify organizers
echo "⏳ Identifying organizers…"
python3 GetTeamDriveOrganizers.py "${SHARED_DRIVE_ACLS}" "${TEAM_DRIVES}" "${TEAM_DRIVE_ORGANIZERS}"

# 12) File counts & sizes
echo "⏳ Fetching file counts & sizes…"
gam config csv_input_row_filter "organizers:regex:^.+$" \
  redirect csv ./"${TEAM_DRIVE_FILE_COUNTS_SIZE}" \
  multiprocess csv ./"${TEAM_DRIVE_ORGANIZERS}" gam user "~organizers" \
    print filecounts select teamdriveid "~id" showsize

# 13) Generate storage info
echo "⏳ Generating storage info…"
python3 GetTeamDriveStorageInfo.py "${TEAM_DRIVE_FILE_COUNTS_SIZE}" "${TEAM_DRIVE_STORAGE_INFO}"

# 14) Last-modified per drive
echo "⏳ Fetching last-modified per drive…"
gam config csv_input_row_filter "organizers:regex:^.+$" \
  redirect csv ./"${TEAM_DRIVE_FILE_LIST}" \
  multiprocess csv ./"${TEAM_DRIVE_ORGANIZERS}" gam user "~organizers" \
    print filelist select teamdriveid "~id" \
    query "mimeType!='application/vnd.google-apps.folder'" \
    fields teamDriveId,id,name,modifiedtime \
    orderby modifiedtime descending maxfiles 1

# 15) Generate last-modified report
echo "⏳ Generating last-modified report…"
python3 GetTeamDriveLastModified.py "${TEAM_DRIVE_FILE_LIST}" "${TEAM_DRIVES}" "${TEAM_DRIVE_LAST_MODIFIED}"

# 16) Normalize headers
echo "⏳ Normalizing CSV headers…"
python3 modify_csv_headers.py

# 17) Merge into 'In Progress'
echo "⏳ Merging into 'In Progress' CSV…"
python3 merge_csv_files.py "${ACST_SHARED_DRIVES}" "${TEAM_DRIVE_STORAGE_INFO}" \
  "${TEAM_DRIVE_LAST_MODIFIED}" "${ACST_SHARED_DRIVES_PROGRESS_CSV}"

# 18) Upload 'In Progress' CSV
echo "⏳ Uploading ${ACST_SHARED_DRIVES_PROGRESS_CSV} to Drive folder ${TARGET_FOLDER_ID}…"
gam user "${UPLOAD_USER}" add drivefile localfile "${ACST_SHARED_DRIVES_PROGRESS_CSV}" \
  drivefilename "${ACST_SHARED_DRIVES_PROGRESS_CSV%.csv}" \
  convert mimetype "application/vnd.google-apps.spreadsheet" \
  parentid "${TARGET_FOLDER_ID}"

echo "✅ All tasks complete!"
