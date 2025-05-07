# Alert System

## Overview
This application is designed to send email notifications to students whose attendance is below par. It integrates Excel data to build messages and send emails, making it versatile beyond just attendance tracking.

## Developer
- **Name:** Aniket Vikramsinh Shinde

## System Architecture

### 1. Core Components
- **Authentication System**
  - Implements Supabase authentication
  - Handles user login/logout flows
  - Manages session state

- **Excel Processing Module**
  - Excel file parsing and data extraction
  - Support for multiple sheets and columns
  - Data mapping and transformation capabilities

- **Email Service**
  - SMTP configuration management
  - Template-based email composition
  - Batch email sending with progress tracking
  - Error handling and reporting

- **Chat System**
  - Integration with Gemini Flash 1.15
  - Message history management
  - Content safety filtering
  - Real-time chat interface

### 2. Data Models
- **StudentData**: Student information and academic records
- **ChatMessage**: Chat interaction data structure
- **EmailTemplate**: Reusable email templates with favorites support
- **ExcelData**: Structured representation of Excel sheet data
- **TaskModel**: Task management and tracking

### 3. Configuration Management
- **API Configuration**: External API keys and endpoints
- **Email Configuration**: SMTP server settings and credentials
- **Supabase Configuration**: Database and authentication settings

### 4. User Interface Components
- **Screens**
  - AuthScreen: User authentication
  - MainScreen: Primary navigation hub
  - AlertSystemScreen: Email notification management
  - ChatScreen: AI chat interface
  - ExcelQueryScreen: Data querying interface
  - EmailSettingsScreen: Email configuration
  - QueryScreen: Advanced data queries
  - SplashScreen: Application loading

- **Widgets**
  - TaskCard: Current task display
  - TaskForm: Task input interface

### 5. Services
- **ChatService**: AI chat functionality
- **EmailService**: Email composition and delivery
- **EmailTemplateService**: Template management
- **ExcelService**: Excel file processing
- **TaskService**: Task operations
- **SheetsService**: Spreadsheet data handling

### 6. Asset Management
- Images and icons for UI elements
- Documentation and support files
- Excel templates and examples

### 7. Platform Support
- Cross-platform compatibility (iOS, Android, Web)
- Native platform configurations
- Responsive design implementation

## Module Interactions and Data Flow

### 1. Authentication Flow
- User credentials → AuthScreen → Supabase Authentication
- Session management through AuthWrapper
- Protected route access via MainScreen

### 2. Data Processing Flow
- Excel file upload → ExcelService → Data validation
- Raw data → ExcelData model → Structured format
- Query processing through ExcelQueryScreen

### 3. Alert Generation Flow
- StudentData → AlertSystemScreen
- Template selection/creation → EmailTemplate
- Batch processing → EmailService → SMTP delivery

### 4. Chat Interaction Flow
- User input → ChatScreen → ChatService
- API request → Gemini Flash 1.15
- Safety filters → Response rendering

### 5. Error Handling Flow
- Service-level error capture
- UI error presentation
- Error logging and reporting

## Security Considerations
- Secure credential storage
- API key protection
- Email authentication
- Data encryption

## Performance Optimization
- Batch email processing
- Efficient Excel parsing
- Caching mechanisms
- Response time optimization

## Additional Functionality
- **Chatbot:** Implemented using Gemini Flash 1.15
- **Template Management:** Save and reuse email templates
- **Progress Tracking:** Real-time email sending progress
- **Data Validation:** Excel data integrity checks
- **Error Handling:** Comprehensive error reporting

## Technical Specifications

### 1. Development Stack
- **Frontend Framework:** Flutter (SDK >=3.0.0 <4.0.0)
- **State Management:** Built-in setState and StreamBuilder
- **Backend Service:** Supabase
- **AI Integration:** Google's Gemini Flash 1.15
- **Email Service:** SMTP with mailer package
- **File Processing:** excel package for Excel operations

### 2. Key Dependencies
- supabase_flutter: ^1.10.25
- http: ^1.1.0
- flutter_markdown: ^0.6.18
- mailer: for email operations
- excel: for Excel file processing
- flutter_secure_storage: for secure credential storage

### 3. Development Requirements
- Flutter SDK
- Dart SDK
- Android Studio/VS Code
- Platform-specific SDKs (Android SDK, Xcode)

### 4. API Integrations
- Supabase API for authentication and data storage
- Gemini API for chat functionality
- SMTP servers for email delivery

## Deployment Guidelines

### 1. Environment Setup
- Configure Supabase credentials
- Set up API keys
- Configure SMTP settings
- Set up development environment

### 2. Build Process
- Flutter clean
- Flutter pub get
- Flutter build for target platform

### 3. Platform-Specific Considerations
- iOS: Code signing and provisioning
- Android: Keystore configuration
- Web: Asset optimization

### 4. Testing Requirements
- Unit tests for services
- Widget tests for UI components
- Integration tests for data flow
- Manual testing checklist
