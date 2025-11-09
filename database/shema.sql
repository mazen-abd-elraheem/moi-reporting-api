-- =============================================
-- MoI Digital Reporting System
-- Azure SQL Database Schema Implementation
-- Core Tables: User, Report, Attachment
-- Squad Alpha: API & Ingestion
-- =============================================

-- Enable optimizations for Azure SQL
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- =============================================
-- Database Configuration for Azure SQL
-- =============================================

-- Set database to use standard performance tier
-- ALTER DATABASE [MoI_Reporting_DB] 
-- MODIFY (SERVICE_OBJECTIVE = 'S2'); -- Adjust based on needs

-- Enable Query Store for performance monitoring
ALTER DATABASE CURRENT SET QUERY_STORE = ON;
GO

-- =============================================
-- User Table
-- =============================================
CREATE TABLE [dbo].[User] (
    [userId] NVARCHAR(450) NOT NULL,
    [isAnonymous] BIT NOT NULL DEFAULT 0,
    [createdAt] DATETIME2(7) NOT NULL DEFAULT GETUTCDATE(),
    [role] NVARCHAR(50) NOT NULL CHECK ([role] IN ('citizen', 'officer', 'admin')),
    [email] NVARCHAR(256) NULL,
    [phoneNumber] NVARCHAR(20) NULL,
    [hashedDeviceId] NVARCHAR(256) NULL,
    
    CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED ([userId] ASC),
    CONSTRAINT [CK_User_ContactInfo] CHECK (
        [isAnonymous] = 1 OR ([email] IS NOT NULL OR [phoneNumber] IS NOT NULL)
    )
);
GO

-- Index for role-based queries
CREATE NONCLUSTERED INDEX [IX_User_Role] 
ON [dbo].[User] ([role]) 
INCLUDE ([userId], [isAnonymous]);
GO

-- Index for device-based lookup (for anonymous users)
CREATE NONCLUSTERED INDEX [IX_User_HashedDeviceId] 
ON [dbo].[User] ([hashedDeviceId]) 
WHERE [hashedDeviceId] IS NOT NULL;
GO

-- =============================================
-- Report Table
-- =============================================
CREATE TABLE [dbo].[Report] (
    [reportId] NVARCHAR(450) NOT NULL,
    [title] NVARCHAR(500) NOT NULL,
    [descriptionText] NVARCHAR(MAX) NOT NULL,
    [location] GEOGRAPHY NOT NULL,
    [status] NVARCHAR(50) NOT NULL DEFAULT 'Submitted' 
        CHECK ([status] IN ('Submitted', 'Assigned', 'InProgress', 'Resolved', 'Rejected')),
    [categoryId] NVARCHAR(100) NOT NULL,
    [aiConfidence] FLOAT NULL CHECK ([aiConfidence] >= 0 AND [aiConfidence] <= 1),
    [createdAt] DATETIME2(7) NOT NULL DEFAULT GETUTCDATE(),
    [updatedAt] DATETIME2(7) NOT NULL DEFAULT GETUTCDATE(),
    [userId] NVARCHAR(450) NULL,
    [transcribedVoiceText] NVARCHAR(MAX) NULL,
    
    CONSTRAINT [PK_Report] PRIMARY KEY CLUSTERED ([reportId] ASC),
    CONSTRAINT [FK_Report_User] FOREIGN KEY ([userId]) 
        REFERENCES [dbo].[User]([userId]) 
        ON DELETE SET NULL
);
GO

-- Index for status-based queries
CREATE NONCLUSTERED INDEX [IX_Report_Status] 
ON [dbo].[Report] ([status]) 
INCLUDE ([reportId], [title], [createdAt]);
GO

-- Index for category-based queries
CREATE NONCLUSTERED INDEX [IX_Report_CategoryId] 
ON [dbo].[Report] ([categoryId]) 
INCLUDE ([reportId], [title], [status]);
GO

-- Index for user's reports
CREATE NONCLUSTERED INDEX [IX_Report_UserId] 
ON [dbo].[Report] ([userId]) 
INCLUDE ([reportId], [title], [status], [createdAt])
WHERE [userId] IS NOT NULL;
GO

-- Spatial index for location-based queries
CREATE SPATIAL INDEX [SIX_Report_Location] 
ON [dbo].[Report] ([location])
USING GEOGRAPHY_GRID
WITH (
    GRIDS = (LEVEL_1 = MEDIUM, LEVEL_2 = MEDIUM, LEVEL_3 = MEDIUM, LEVEL_4 = MEDIUM),
    CELLS_PER_OBJECT = 16
);
GO

-- Index for date-based queries
CREATE NONCLUSTERED INDEX [IX_Report_CreatedAt] 
ON [dbo].[Report] ([createdAt] DESC) 
INCLUDE ([reportId], [status], [categoryId]);
GO

-- =============================================
-- Attachment Table
-- =============================================
CREATE TABLE [dbo].[Attachment] (
    [attachmentId] NVARCHAR(450) NOT NULL,
    [reportId] NVARCHAR(450) NOT NULL,
    [blobStorageUri] NVARCHAR(2048) NOT NULL,
    [mimeType] NVARCHAR(100) NOT NULL,
    [fileType] NVARCHAR(50) NOT NULL 
        CHECK ([fileType] IN ('image', 'video', 'audio', 'document')),
    [fileSizeBytes] BIGINT NOT NULL CHECK ([fileSizeBytes] > 0),
    
    CONSTRAINT [PK_Attachment] PRIMARY KEY CLUSTERED ([attachmentId] ASC),
    CONSTRAINT [FK_Attachment_Report] FOREIGN KEY ([reportId]) 
        REFERENCES [dbo].[Report]([reportId]) 
        ON DELETE CASCADE
);
GO

-- Index for retrieving attachments by report
CREATE NONCLUSTERED INDEX [IX_Attachment_ReportId] 
ON [dbo].[Attachment] ([reportId]) 
INCLUDE ([attachmentId], [fileType], [mimeType]);
GO

-- Index for file type queries
CREATE NONCLUSTERED INDEX [IX_Attachment_FileType] 
ON [dbo].[Attachment] ([fileType]) 
INCLUDE ([attachmentId], [reportId]);
GO

-- =============================================
-- Trigger to auto-update Report.updatedAt
-- =============================================
CREATE TRIGGER [dbo].[TR_Report_UpdateTimestamp]
ON [dbo].[Report]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE [dbo].[Report]
    SET [updatedAt] = GETUTCDATE()
    FROM [dbo].[Report] r
    INNER JOIN inserted i ON r.[reportId] = i.[reportId]
    WHERE r.[updatedAt] = i.[updatedAt]; -- Only update if not manually set
END;
GO

-- =============================================
-- Useful Views
-- =============================================

-- View for reports with attachment counts
CREATE VIEW [dbo].[vw_ReportSummary]
AS
SELECT 
    r.[reportId],
    r.[title],
    r.[status],
    r.[categoryId],
    r.[createdAt],
    r.[updatedAt],
    r.[userId],
    r.[location],
    r.[aiConfidence],
    u.[email] AS [userEmail],
    u.[role] AS [userRole],
    u.[isAnonymous],
    COUNT(a.[attachmentId]) AS [attachmentCount]
FROM [dbo].[Report] r
LEFT JOIN [dbo].[User] u ON r.[userId] = u.[userId]
LEFT JOIN [dbo].[Attachment] a ON r.[reportId] = a.[reportId]
GROUP BY 
    r.[reportId], r.[title], r.[status], r.[categoryId], 
    r.[createdAt], r.[updatedAt], r.[userId], r.[location],
    r.[aiConfidence], u.[email], u.[role], u.[isAnonymous];
GO

-- =============================================
-- Sample Data for Testing (Optional)
-- =============================================

-- Insert sample users
INSERT INTO [dbo].[User] ([userId], [isAnonymous], [role], [email], [phoneNumber])
VALUES 
    ('user-001', 0, 'citizen', 'john.doe@example.com', '+1234567890'),
    ('user-002', 0, 'officer', 'officer@city.gov', '+1987654321'),
    ('user-003', 0, 'admin', 'admin@city.gov', NULL),
    ('anon-001', 1, 'citizen', NULL, NULL);
GO

-- Insert sample reports with geography points
-- Example: Cairo coordinates (30.0444, 31.2357)
INSERT INTO [dbo].[Report] 
    ([reportId], [title], [descriptionText], [location], [status], [categoryId], [userId], [aiConfidence])
VALUES 
    ('report-001', 
     'Pothole on Main Street', 
     'Large pothole causing traffic issues', 
     geography::Point(30.0444, 31.2357, 4326),
     'Submitted', 
     'infrastructure', 
     'user-001',
     0.92),
    ('report-002', 
     'Streetlight malfunction', 
     'Broken streetlight near park entrance', 
     geography::Point(30.0450, 31.2360, 4326),
     'Assigned', 
     'utilities', 
     'user-001',
     0.88);
GO

-- Insert sample attachments
INSERT INTO [dbo].[Attachment] 
    ([attachmentId], [reportId], [blobStorageUri], [mimeType], [fileType], [fileSizeBytes])
VALUES 
    ('attach-001', 'report-001', 'https://storage.blob.core.windows.net/reports/img001.jpg', 'image/jpeg', 'image', 2048576),
    ('attach-002', 'report-001', 'https://storage.blob.core.windows.net/reports/vid001.mp4', 'video/mp4', 'video', 10485760);
GO

-- =============================================
-- Verification Queries
-- =============================================

-- Check table structures
SELECT 
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLength,
    c.is_nullable AS IsNullable
FROM sys.tables t
INNER JOIN sys.columns c ON t.object_id = c.object_id
INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
WHERE t.name IN ('User', 'Report', 'Attachment')
ORDER BY t.name, c.column_id;
GO

-- Verify indexes
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE t.name IN ('User', 'Report', 'Attachment')
    AND i.name IS NOT NULL
ORDER BY t.name, i.name;
GO