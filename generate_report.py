import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from PIL import Image
import numpy as np

# Load the data
df = pd.read_csv('SharedDrivesActivity.csv', low_memory=False)
df['date'] = pd.to_datetime(df['id.time'], errors='coerce').dt.date

# Prepare metrics
daily_counts = df.groupby('date').size()
top_events = df['name'].value_counts().nlargest(10)
top_users = df['actor.email'].value_counts().nlargest(10)
top_drives = df['shared_drive_name'].value_counts().nlargest(10)
df['weekday'] = pd.to_datetime(df['date']).dt.day_name()
weekday_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
weekday_counts = df['weekday'].value_counts().reindex(weekday_order).fillna(0)

# Load logo image

# Generate PDF with cover and charts
pdf_path = 'activity_report_with_cover.pdf'
with PdfPages(pdf_path) as pdf:
    # Cover Page
    fig = plt.figure(figsize=(8.27, 11.69))  # A4 size in inches
    fig.patch.set_facecolor('white')
    ax_cover = fig.add_axes([0, 0, 1, 1])
    ax_cover.axis('off')
    # Draw logo at top center
    
    # Title text
    fig.text(0.5, 0.5, 'Last 500 Activity Report\nfor All Shared Drives',
             ha='center', va='center', fontsize=24, weight='bold')
    pdf.savefig(fig)
    plt.close(fig)

    # 1) Activity Over Time
    fig, ax = plt.subplots(figsize=(8, 6))
    daily_counts.plot(ax=ax, kind='line', marker='o', color='#15224c')
    ax.set_title('Daily Shared Drive Activities')
    ax.set_xlabel('Date')
    ax.set_ylabel('Number of Activities')
    plt.tight_layout()
    pdf.savefig(fig)
    plt.close(fig)

    # 2) Top 10 Activity Types
    fig, ax = plt.subplots(figsize=(8, 6))
    top_events.plot(ax=ax, kind='bar', color='#2f8bbe')
    ax.set_title('Top 10 Activity Types')
    ax.set_xlabel('Activity Type')
    ax.set_ylabel('Count')
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    pdf.savefig(fig)
    plt.close(fig)

    # 3) Top 10 Users by Activity
    fig, ax = plt.subplots(figsize=(8, 6))
    top_users.plot(ax=ax, kind='bar', color='#2f8bbe')
    ax.set_title('Top 10 Users by Shared Drive Activity')
    ax.set_xlabel('User Email')
    ax.set_ylabel('Count')
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    pdf.savefig(fig)
    plt.close(fig)

    # 4) Top 10 Shared Drives by Activity
    fig, ax = plt.subplots(figsize=(8, 6))
    top_drives.plot(ax=ax, kind='bar', color='#2f8bbe')
    ax.set_title('Top 10 Shared Drives by Activity')
    ax.set_xlabel('Shared Drive Name')
    ax.set_ylabel('Count')
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    pdf.savefig(fig)
    plt.close(fig)

    # 5) Shared Drive Activity by Day of Week
    fig, ax = plt.subplots(figsize=(8, 6))
    weekday_counts.plot(ax=ax, kind='bar', color='#2f8bbe')
    ax.set_title('Activity by Day of Week')
    ax.set_xlabel('Day of Week')
    ax.set_ylabel('Count')
    plt.tight_layout()
    pdf.savefig(fig)
    plt.close(fig)

print(f"Generated PDF with cover page: {pdf_path}")
