-- =============================================
-- MoI Digital Reporting System
-- Azure SQL: Operational + Analytics (Hot/Cold)
-- Core OLTP tables in dbo
-- Analytics tables in hot (recent) and cold (historical)
-- =============================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Create schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'hot')
    EXEC('CREATE SCHEMA [hot]');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cold')
    EXEC('CREATE SCHEMA [cold]');
GO

-- Enable Query Store
ALTER DATABASE CURRENT SET QUERY_STORE = ON;
GO

-- =============================================
-- OPERATIONAL TABLES (OLTP) — remain in dbo
-- =============================================

CREATE TABLE [dbo].[User] (
    [userId] NVARCHAR(450) NOT NULL,
    [isAnonymous] BIT NOT NULL DEFAULT 0,
    [createdAt] DATETIME2(7) NOT NULL DEFAULT GETUTCDATE(),
    [role] NVARCHAR(50) NOT NULL CHECK ([role] IN ('citizen', 'officer', 'admin')),
    [email] NVARCHAR(256) NULL,
    [phoneNumber] NVARCHAR(20) NULL,
    [hashedDeviceId] NVARCHAR(256) NULL,
    CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED ([userId]),
    CONSTRAINT [CK_User_ContactInfo] CHECK ([isAnonymous] = 1 OR [email] IS NOT NULL OR [phoneNumber] IS NOT NULL)
);
GO

CREATE TABLE [dbo].[Report] (
    [reportId] NVARCHAR(450) NOT NULL,
    [title] NVARCHAR(500) NOT NULL,
    [descriptionText] NVARCHAR(MAX) NOT NULL,
    [locationRaw] NVARCHAR(2048) NULL,
    [status] NVARCHAR(50) NOT NULL DEFAULT 'Submitted'
        CHECK ([status] IN ('Submitted', 'Assigned', 'InProgress', 'Resolved', 'Rejected')),
    [categoryId] NVARCHAR(100) NOT NULL,
    [aiConfidence] FLOAT NULL CHECK ([aiConfidence] >= 0 AND [aiConfidence] <= 1),
    [createdAt] DATETIME2(7) NOT NULL DEFAULT GETUTCDATE(),
    [updatedAt] DATETIME2(7) NOT NULL DEFAULT GETUTCDATE(),
    [userId] NVARCHAR(450) NULL,
    [transcribedVoiceText] NVARCHAR(MAX) NULL,
    CONSTRAINT [PK_Report] PRIMARY KEY CLUSTERED ([reportId]),
    CONSTRAINT [FK_Report_User] FOREIGN KEY ([userId]) REFERENCES [dbo].[User]([userId]) ON DELETE SET NULL
);
GO

CREATE TABLE [dbo].[Attachment] (
    [attachmentId] NVARCHAR(450) NOT NULL,
    [reportId] NVARCHAR(450) NOT NULL,
    [blobStorageUri] NVARCHAR(2048) NOT NULL,
    [mimeType] NVARCHAR(100) NOT NULL,
    [fileType] NVARCHAR(50) NOT NULL CHECK ([fileType] IN ('image', 'video', 'audio')),
    [fileSizeBytes] BIGINT NOT NULL CHECK ([fileSizeBytes] > 0),
    CONSTRAINT [PK_Attachment] PRIMARY KEY CLUSTERED ([attachmentId]),
    CONSTRAINT [FK_Attachment_Report] FOREIGN KEY ([reportId]) REFERENCES [dbo].[Report]([reportId]) ON DELETE CASCADE
);
GO

-- Operational indexes (as before)
CREATE NONCLUSTERED INDEX [IX_User_Role] ON [dbo].[User] ([role]) INCLUDE ([userId], [isAnonymous]);
CREATE NONCLUSTERED INDEX [IX_User_HashedDeviceId] ON [dbo].[User] ([hashedDeviceId]) WHERE [hashedDeviceId] IS NOT NULL;
CREATE NONCLUSTERED INDEX [IX_Report_Status] ON [dbo].[Report] ([status]) INCLUDE ([reportId], [title], [createdAt]);
CREATE NONCLUSTERED INDEX [IX_Report_CategoryId] ON [dbo].[Report] ([categoryId]) INCLUDE ([reportId], [title], [status]);
CREATE NONCLUSTERED INDEX [IX_Report_UserId] ON [dbo].[Report] ([userId]) INCLUDE ([reportId], [title], [status], [createdAt]) WHERE [userId] IS NOT NULL;
CREATE NONCLUSTERED INDEX [IX_Report_CreatedAt] ON [dbo].[Report] ([createdAt] DESC) INCLUDE ([reportId], [status], [categoryId]);
CREATE NONCLUSTERED INDEX [IX_Report_LocationRaw] ON [dbo].[Report] ([locationRaw]) WHERE [locationRaw] IS NOT NULL;
CREATE NONCLUSTERED INDEX [IX_Attachment_ReportId] ON [dbo].[Attachment] ([reportId]) INCLUDE ([attachmentId], [fileType], [mimeType]);
CREATE NONCLUSTERED INDEX [IX_Attachment_FileType] ON [dbo].[Attachment] ([fileType]) INCLUDE ([attachmentId], [reportId]);
GO

-- Trigger for operational table
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
    WHERE r.[updatedAt] = i.[updatedAt];
END;
GO

-- =============================================
-- ANALYTICS LAYER (for reporting & dashboards)
-- =============================================

-- Example: Materialized analytics table (you'd refresh via job)
-- Hot analytics: reports from last 90 days
CREATE TABLE [hot].[ReportAnalytics] (
    [reportId] NVARCHAR(450) NOT NULL,
    [title] NVARCHAR(500) NOT NULL,
    [status] NVARCHAR(50) NOT NULL,
    [categoryId] NVARCHAR(100) NOT NULL,
    [createdAt] DATETIME2(7) NOT NULL,
    [userId] NVARCHAR(450) NULL,
    [userRole] NVARCHAR(50) NULL,
    [isAnonymous] BIT NULL,
    [attachmentCount] INT NOT NULL DEFAULT 0,
    [aiConfidence] FLOAT NULL,
    INDEX IX_Hot_CreatedAt ([createdAt]),
    INDEX IX_Hot_Status ([status]),
    INDEX IX_Hot_Category ([categoryId])
);
GO

-- Cold analytics: reports older than 90 days (archival analytics)
CREATE TABLE [cold].[ReportAnalytics] (
    [reportId] NVARCHAR(450) NOT NULL,
    [status] NVARCHAR(50) NOT NULL,
    [categoryId] NVARCHAR(100) NOT NULL,
    [createdAt] DATETIME2(7) NOT NULL,
    [userRole] NVARCHAR(50) NULL,
    [isAnonymous] BIT NULL,
    [attachmentCount] INT NOT NULL DEFAULT 0,
    [aiConfidence] FLOAT NULL,
    INDEX IX_Cold_CreatedAt ([createdAt]),
    INDEX IX_Cold_Status ([status])
);
GO

-- Optional: Unified view across hot + cold analytics (for full history)
CREATE VIEW [dbo].[vw_FullReportAnalytics] AS
SELECT * FROM [hot].[ReportAnalytics]
UNION ALL
SELECT * FROM [cold].[ReportAnalytics];
GO

-- Example: Populate hot analytics (run via Azure Function or SQL Agent)
/*
INSERT INTO [hot].[ReportAnalytics]
SELECT 
    r.reportId,
    r.title,
    r.status,
    r.categoryId,
    r.createdAt,
    r.userId,
    u.role AS userRole,
    u.isAnonymous,
    COUNT(a.attachmentId) AS attachmentCount,
    r.aiConfidence
FROM dbo.Report r
LEFT JOIN dbo.User u ON r.userId = u.userId
LEFT JOIN dbo.Attachment a ON r.reportId = a.reportId
WHERE r.createdAt >= DATEADD(DAY, -90, GETUTCDATE())
GROUP BY r.reportId, r.title, r.status, r.categoryId, r.createdAt, r.userId, u.role, u.isAnonymous, r.aiConfidence;
*/

-- =============================================
-- Operational view (unchanged, for app layer)
-- =============================================
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
    r.[locationRaw],
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
    r.[createdAt], r.[updatedAt], r.[userId], r.[locationRaw],
    r.[aiConfidence], u.[email], u.[role], u.[isAnonymous];
GO

-- =============================================
-- Verification
-- =============================================
SELECT s.name AS SchemaName, t.name AS TableName
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.name IN ('User', 'Report', 'Attachment', 'ReportAnalytics')
ORDER BY s.name, t.name;
GO