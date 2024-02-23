# Jira Worklog Manager

The Jira Worklog Manager is a specialized app designed to streamline the process of monitoring and reporting worklogs directly within Jira. This app stands out as an essential tool for professionals who rely on Jira for project management and time tracking. It offers an intuitive and user-friendly interface that simplifies the task of reviewing and managing worklogs.

## Key Features:

![Main Window](https://github.com/luisfgfurtado/jira_time_ctrl/blob/main/res/mainwindow.png?raw=true)
![Test](https://github.com/luisfgfurtado/jira_time_ctrl/blob/main/res/openworklog.png?raw=true | width=300)
![Edit worklog](https://github.com/luisfgfurtado/jira_time_ctrl/blob/main/res/editworklog.png?raw=true | width=300)
<img src="https://github.com/luisfgfurtado/jira_time_ctrl/blob/main/res/editworklog.png?raw=true" width="300">

1. **Efficient Worklog Viewing:** Easily view detailed worklogs for each issue, organized by week. This feature allows users to quickly assess time spent on various tasks and projects.

1. **Interactive Time Tracking:** Add, edit, or delete worklogs with ease. The app provides a straightforward way to log hours, ensuring accurate and up-to-date time tracking.

1. **Customizable Views:** Adjust views to include weekends and filter tasks assigned specifically to you. This customization enhances the relevance and focus of the data displayed.

1. **Streamlined Issue Management:** Directly access issue details through clickable links. This integration with Jira enhances workflow efficiency by connecting worklog data with corresponding issues.

1. **Responsive Design:** The app's responsive layout adapts to different screen sizes, making it accessible on various devices. This flexibility ensures a seamless user experience, regardless of how you access the app.

1. **Advanced Sorting and Filtering:** Sort and filter worklogs based on different criteria, including project, issue key, and more. This feature aids in organizing and prioritizing worklogs for analysis and reporting.

1. **Local Data Storage:** Save user preferences and window settings locally for a personalized and consistent experience.

Jira Worklog Manager is designed to be a powerful companion for anyone looking to optimize their time management and reporting within the Jira ecosystem. It simplifies the often complex task of worklog tracking, offering clarity and control over your time and project progress.

## Get Started: Downloading and Using the Windows Application

To begin using the Timesheet Application for Jira, download the application from the releases page.

## Setup: Configuring the Application

1. **API URL:** In the configuration, enter the API URL for your Jira instance. This is the base URL used to access your Jira account.
1. **API Key:**
To obtain an API key, log in to your Jira account.
Navigate to "Account Settings" and select "API Tokens".
Click on "Create API Token". Give it a name and copy the generated token.
Paste this API key in the application's settings.
1. **Timesheet Added Issues:** Enable this option to manually add specific issues to your timesheet, providing more control over the entries.
1. **Timesheet JQL:** Customize the Jira Query Language (JQL) to refine the issues that appear in your timesheet. This allows for a more tailored view based on your specific needs or projects.
1. **Tempo Worklog Period:** Set the number of past days you want to retrieve worklog entries for. This helps focus on recent activities without clutter from older entries.
1. **Check API Connection:** Use this button to verify if the application can successfully connect to the Jira Rest API with the provided settings.
1. **Save:** After configuring the settings, click on the 'Save' button to apply and store these configurations.
Remember to save your settings after making changes to ensure your application is configured correctly for your specific Jira environment.

## Build installer

1. Check https://pub.dev/packages/msix#github-settings-icon-configuring-your-installer
1. run ''dart run msix:publish''