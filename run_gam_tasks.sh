#!/bin/bash

# ————————————
# Add GAM to PATH (adjust if necessary)
export PATH="$HOME/bin/gamadv-xtd3:$PATH"

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

# Single Shared Drive ID for per-user report
SHARED_DRIVE_ID="0AFYbD8kOZbrpUk9PVA"

# Upload settings
target_folder_id="1Kfm9kLh_M7xuKtArJvvUQ-2p1bLARM9E"
upload_user="gamserviceaccount@acst.net"

today=$(date +%Y-%m-%d)

# ————————————
# Preconditions
if ! command -v gam &> /dev/null; then
  echo "Error: GAM not found in PATH." >&2
  exit 1
fi
if ! command -v python3 &> /dev/null; then
  echo "Error: Python3 not found." >&2
  exit 1
fi


#————————————

# 1) Fetch Shared Drives list
echo "Fetching Shared Drives list…"
gam redirect csv ./${SHARED_DRIVES_LIST} print shareddrives fields id,name

# 2) Fetch Shared Drives activity (last 30 days)
echo "Fetching Shared Drives activity for the past 30 days…"
gam redirect csv ./${SHARED_DRIVES_ACTIVITY} \
  multiprocess redirect stderr - \
  multiprocess csv ${SHARED_DRIVES_LIST} \
  gam report drive start -30d end today \
    filter "shared_drive_id==~~id~~" \
    addcsvdata shared_drive_id "~id" \
    addcsvdata shared_drive_name "~name"

# 2a) Upload Shared Drives activity sheet to Drive
echo "Uploading ${SHARED_DRIVES_ACTIVITY} to Drive folder ${target_folder_id}…"
gam user ${upload_user} add drivefile localfile "${SHARED_DRIVES_ACTIVITY}" \
  drivefilename "${SHARED_DRIVES_ACTIVITY%.csv}" \
  convert \
  mimetype "application/vnd.google-apps.spreadsheet" \
  parentid "${target_folder_id}"

# 3) Fetch per-user activity for drive ${SHARED_DRIVE_ID}
echo "Fetching per-user activity for drive ${SHARED_DRIVE_ID}…"
csv_file="driveactivity_${SHARED_DRIVE_ID}_${today}.csv"
gam report drive user all start -30d end today \
  filter "shared_drive_id==${SHARED_DRIVE_ID}" > "${csv_file}"

# 3a) Upload per-user activity to Drive
echo "Uploading ${csv_file} to Drive folder ${target_folder_id}…"
gam user ${upload_user} add drivefile localfile "${csv_file}" \
  drivefilename "${csv_file%.csv}" \
  convert \
  mimetype "application/vnd.google-apps.spreadsheet" \
  parentid "${target_folder_id}"



# ————————————
# 1) Fetch Shared-Drive ACLs
echo "Fetching Shared-Drive ACLs…"
gam redirect csv ./${TEAM_DRIVE_ACLS} print teamdriveacls \
  fields id,domain,emailaddress,role,type,deleted oneitemperrow

# 2) Fetch group members
echo "Fetching group members…"
gam redirect csv ./${GROUP_MEMBERS} print groups \
  roles members,managers,owners delimiter " "

# 3) Expand group ACLs
echo "Expanding group ACLs…"
python3 GetTeamDriveACLsExpandGroups.py "${TEAM_DRIVE_ACLS}" "${GROUP_MEMBERS}" "${EXPANDED_ACLS}"

# 4) Fetch team drives
echo "Fetching Team Drives…"
gam redirect csv ./${TEAM_DRIVES} print teamdrives fields id,name

# 5) Fetch all team drives with organizers
gam redirect csv ./${ALL_TEAM_DRIVES} print teamdrives role organizer fields id,name

# 6) Remove duplicates
echo "Removing duplicates…"
python3 DeleteDuplicateRows.py "${ALL_TEAM_DRIVES}" "${TEAM_DRIVES}"

# 7) File ACLs per drive
echo "Fetching file ACLs per drive…"
gam redirect csv ./${TEAM_DRIVE_ACLS} multiprocess csv ./${TEAM_DRIVES} gam print drivefileacls "~id" \
  fields emailaddress,role,type

# 8) Identify organizers
echo "Identifying organizers…"
python3 GetTeamDriveOrganizers.py "${TEAM_DRIVE_ACLS}" "${TEAM_DRIVES}" "${TEAM_DRIVE_ORGANIZERS}"

# 9) File counts & sizes
echo "Fetching file counts & sizes…"
gam config csv_input_row_filter "organizers:regex:^.+$" \
    redirect csv ./${TEAM_DRIVE_FILE_COUNTS_SIZE} \
    multiprocess csv ./${TEAM_DRIVE_ORGANIZERS} gam user "~organizers" \
      print filecounts select teamdriveid "~id" showsize

# 10) Generate storage info
echo "Generating storage info…"
python3 GetTeamDriveStorageInfo.py "${TEAM_DRIVE_FILE_COUNTS_SIZE}" "${TEAM_DRIVE_STORAGE_INFO}"

# 11) Last-modified per drive
echo "Fetching last-modified per drive…"
gam config csv_input_row_filter "organizers:regex:^.+$" \
    redirect csv ./${TEAM_DRIVE_FILE_LIST} \
    multiprocess csv ./${TEAM_DRIVE_ORGANIZERS} gam user "~organizers" \
      print filelist select teamdriveid "~id" \
      query "mimeType != 'application/vnd.google-apps.folder'" \
      fields teamDriveId,id,name,modifiedtime \
      orderby modifiedtime descending maxfiles 1

# 12) Generate last-modified report
echo "Generating last-modified report…"
python3 GetTeamDriveLastModified.py "${TEAM_DRIVE_FILE_LIST}" "${TEAM_DRIVES}" "${TEAM_DRIVE_LAST_MODIFIED}"





# 13) Normalize headers
echo "Normalizing CSV headers…"
python3 modify_csv_headers.py

# 14) Merge into 'In Progress'
echo "Merging into 'In Progress' CSV…"
python3 merge_csv_files.py "${ACST_SHARED_DRIVES}" "${TEAM_DRIVE_STORAGE_INFO}" \
  "${TEAM_DRIVE_LAST_MODIFIED}" "${ACST_SHARED_DRIVES_PROGRESS_CSV}"

# 13a) Upload 'In Progress' CSV to Drive
echo "Uploading ${ACST_SHARED_DRIVES_PROGRESS_CSV} to Drive folder ${target_folder_id}…"
gam user ${upload_user} add drivefile localfile "${ACST_SHARED_DRIVES_PROGRESS_CSV}" \
  drivefilename "${ACST_SHARED_DRIVES_PROGRESS_CSV%.csv}" \
  convert \
  mimetype "application/vnd.google-apps.spreadsheet" \
  parentid "${target_folder_id}"



# ————————————
echo "✅ All tasks complete!"
