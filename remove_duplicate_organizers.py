import pandas as pd
import sys

def remove_duplicate_organizers(input_csv, output_csv):
    try:
        # Load the original CSV
        df = pd.read_csv(input_csv, encoding='utf-8')
        print(f"Loaded '{input_csv}' successfully.")

        # Ensure required columns exist
        required_columns = ['id', 'name', 'createdTime', 'emailAddress', 'role', 'type']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            print(f"Error: Missing required columns: {', '.join(missing_columns)}", file=sys.stderr)
            return

        # Identify rows with role 'organizer' (case-insensitive)
        organizer_mask = df['role'].str.lower() == 'organizer'

        # Separate organizers and non-organizers
        organizers = df[organizer_mask].copy()
        non_organizers = df[~organizer_mask].copy()

        print(f"Found {len(organizers)} organizer entries.")

        # Remove duplicates: keep only one organizer per Team Drive (first occurrence)
        organizers_unique = organizers.drop_duplicates(subset=['id', 'name', 'emailAddress'], keep='first')
        duplicates_removed = len(organizers) - len(organizers_unique)
        print(f"Removed {duplicates_removed} duplicate organizer entries.")

        # **Optional:** If you want to keep only **one** organizer per Team Drive regardless of emailAddress:
        # Uncomment the following lines:
        # organizers_unique = organizers.drop_duplicates(subset=['id', 'name'], keep='first')
        # duplicates_removed = len(organizers) - len(organizers_unique)
        # print(f"Removed {duplicates_removed} duplicate organizer entries.")

        # Combine non-organizer roles with unique organizers
        df_cleaned = pd.concat([non_organizers, organizers_unique], ignore_index=True)

        # **Optional:** Sort the DataFrame for better readability
        df_cleaned = df_cleaned.sort_values(by=['id', 'name', 'emailAddress'])

        # Save the cleaned DataFrame to a new CSV
        df_cleaned.to_csv(output_csv, index=False, encoding='utf-8')
        print(f"Successfully saved cleaned data to '{output_csv}'.")

    except FileNotFoundError:
        print(f"Error: The file '{input_csv}' does not exist.", file=sys.stderr)
    except pd.errors.EmptyDataError:
        print(f"Error: The file '{input_csv}' is empty.", file=sys.stderr)
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)

if __name__ == "__main__":
    # Define input and output CSV file paths
    input_csv = 'NormalizedTeamDriveACLs.csv'  # Replace with your actual input CSV file name
    output_csv = 'storage.csv'  # Desired name for the new CSV file

    # **Optional:** Allow passing file names as command-line arguments
    if len(sys.argv) == 3:
        input_csv = sys.argv[1]
        output_csv = sys.argv[2]
    elif len(sys.argv) != 1:
        print("Usage: python remove_duplicate_organizers.py [input_csv] [output_csv]", file=sys.stderr)
        sys.exit(1)

    remove_duplicate_organizers(input_csv, output_csv)
