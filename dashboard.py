import pandas as pd
import plotly.express as px
from dash import Dash, dcc, html, Input, Output
import webbrowser

# Step 1: Read the CSV file
try:
    df = pd.read_csv('SharedDrivesActivity.csv', low_memory=False)
except FileNotFoundError:
    raise FileNotFoundError("Error: 'SharedDrivesActivity.csv' not found in the current directory. Please ensure the file is present.")

# Step 2: Clean the data
# Remove rows with 'NoActivities'
df = df[df['name'] != 'NoActivities']
# Convert id.time to datetime
df['id.time'] = pd.to_datetime(df['id.time'], errors='coerce')
# Drop rows with missing critical columns
df = df.dropna(subset=['type', 'doc_title', 'actor.email'])
# Extract date for time-based analysis
df['date'] = df['id.time'].dt.date

# Step 3: Initialize Dash app
app = Dash(__name__)

# Step 4: Define dashboard layout
app.layout = html.Div([
    html.H1('Google Drive Audit Dashboard', className='text-2xl font-bold mb-4'),
    dcc.Graph(id='actions-over-time'),
    dcc.Graph(id='action-type-pie'),
    dcc.Graph(id='document-activity-bar'),
    dcc.Graph(id='activity-chart'),
    html.P(id='insight', className='mt-4 text-lg italic'),
], className='container mx-auto p-4')

# Step 5: Callback to update charts
@app.callback(
    [Output('actions-over-time', 'figure'),
     Output('action-type-pie', 'figure'),
     Output('document-activity-bar', 'figure'),
     Output('activity-chart', 'figure'),
     Output('insight', 'children')],
    Input('actions-over-time', 'id')  # Trigger on load
)
def update_dashboard(_):
    # Actions over time (line chart)
    actions_over_time = df.groupby('date').size().reset_index(name='count')
    fig1 = px.line(actions_over_time, x='date', y='count', title='Actions Over Time',
                   labels={'date': 'Date', 'count': 'Number of Actions'},
                   template='plotly_white')

    # Action type distribution (pie chart) - Include all specified types
    all_action_types = ['view', 'copy', 'edit', 'sync_item_content', 'move', 'change_owner', 
                        'create', 'source_copy', 'upload', 'rename', 'change_user_access']
    # Count occurrences of each action type in the data
    action_types = df['type'].value_counts().reset_index(name='count')
    action_types.columns = ['type', 'count']
    # Create a DataFrame with all specified action types, filling missing ones with 0
    action_types_dict = {action: 0 for action in all_action_types}
    for _, row in action_types.iterrows():
        if row['type'] in all_action_types:
            action_types_dict[row['type']] = row['count']
    action_types_df = pd.DataFrame(list(action_types_dict.items()), columns=['type', 'count'])
    fig2 = px.pie(action_types_df, names='type', values='count', title='Action Type Distribution',
                  template='plotly_white')
    fig2.update_traces(textinfo='percent+label', textposition='inside')  # Show labels and percentages
    fig2.update_layout(legend_title_text='Action Types')  # Fix: Use legend_title_text instead of show_title

    # Document activity (bar chart)
    doc_activity = df.groupby('doc_title').size().reset_index(name='count')
    fig3 = px.bar(doc_activity, x='doc_title', y='count', title='Activity by Document',
                  labels={'doc_title': 'Document Title', 'count': 'Number of Actions'},
                  template='plotly_white')
    fig3.update_layout(xaxis_tickangle=45)

    # Stacked bar chart (replacing table) with clear labels
    top_docs = df.groupby('doc_title').size().nlargest(10).index
    filtered_df = df[df['doc_title'].isin(top_docs)]
    summary = filtered_df.groupby(['doc_title', 'type', 'actor.email']).size().reset_index(name='count')
    fig4 = px.bar(summary, x='doc_title', y='count', color='actor.email', barmode='stack',
                  facet_col='type', title='Actions by Document, Type, and User',
                  labels={'doc_title': 'Document Title', 'count': 'Number of Actions', 'actor.email': 'User'},
                  template='plotly_white')
    fig4.update_layout(
        xaxis_tickangle=45,
        height=600,
        legend=dict(
            title='User',
            orientation='h',
            yanchor='bottom',
            y=1.02,
            xanchor='right',
            x=1
        ),
        margin=dict(l=40, r=40, t=100, b=100),
        xaxis_title='Document Title',
        yaxis_title='Number of Actions'
    )

    # Interesting insight
    most_active_user = df['actor.email'].value_counts().idxmax()
    insight = f"Interesting Fact: {most_active_user} is the most active user, with significant activity on 'M26 IBDP Registration'."

    return fig1, fig2, fig3, fig4, insight

# Step 6: Run the app and open in browser
if __name__ == '__main__':
    server_ip = '192.168.1.15'  # Your machine's IP
    port = 8050
    url = f'http://{server_ip}:{port}'
    webbrowser.open(url)
    app.run(debug=False, host=server_ip, port=port)