:setvar DatabaseName "sre_demo"

ALTER DATABASE [$(DatabaseName)] SET QUERY_STORE = ON;
ALTER DATABASE [$(DatabaseName)] SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,
    DATA_FLUSH_INTERVAL_SECONDS = 60,
    INTERVAL_LENGTH_MINUTES = 5,
    MAX_STORAGE_SIZE_MB = 256,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 7)
);
GO

USE [$(DatabaseName)];
GO

IF OBJECT_ID(N'dbo.Inventory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Inventory
    (
        ProductId int NOT NULL CONSTRAINT PK_Inventory PRIMARY KEY,
        ProductName nvarchar(100) NOT NULL,
        AvailableQuantity int NOT NULL,
        ReservedQuantity int NOT NULL CONSTRAINT DF_Inventory_Reserved DEFAULT (0),
        LastUpdatedUtc datetime2(0) NOT NULL CONSTRAINT DF_Inventory_LastUpdated DEFAULT (SYSUTCDATETIME())
    );

    INSERT dbo.Inventory (ProductId, ProductName, AvailableQuantity)
    VALUES (1, N'Contoso industrial controller', 5000);
END;
GO

IF OBJECT_ID(N'dbo.SalesOrders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SalesOrders
    (
        OrderId bigint NOT NULL CONSTRAINT PK_SalesOrders PRIMARY KEY,
        CustomerId int NOT NULL,
        ProductId int NOT NULL,
        Quantity int NOT NULL,
        UnitPrice decimal(12, 2) NOT NULL,
        OrderDateUtc datetime2(0) NOT NULL,
        Status varchar(20) NOT NULL
    );

    WITH Numbers AS
    (
        SELECT TOP (100000)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Number
        FROM sys.all_objects AS first_set
        CROSS JOIN sys.all_objects AS second_set
    )
    INSERT dbo.SalesOrders
    (
        OrderId,
        CustomerId,
        ProductId,
        Quantity,
        UnitPrice,
        OrderDateUtc,
        Status
    )
    SELECT
        Number,
        (Number % 2500) + 1,
        1,
        (Number % 8) + 1,
        CAST(25 + (Number % 500) AS decimal(12, 2)),
        DATEADD(minute, -Number, SYSUTCDATETIME()),
        CASE WHEN Number % 10 = 0 THEN 'Pending' ELSE 'Completed' END
    FROM Numbers;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetCustomerOrderSummary
    @CustomerId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CustomerId,
        COUNT_BIG(*) AS OrderCount,
        SUM(Quantity * UnitPrice) AS TotalValue,
        MAX(OrderDateUtc) AS LatestOrderUtc
    FROM dbo.SalesOrders
    WHERE CustomerId = @CustomerId
    GROUP BY CustomerId;
END;
GO

UPDATE dbo.Inventory
SET ReservedQuantity = 0,
    LastUpdatedUtc = SYSUTCDATETIME()
WHERE ProductId = 1;
GO

EXEC dbo.usp_GetCustomerOrderSummary @CustomerId = 42;
EXEC dbo.usp_GetCustomerOrderSummary @CustomerId = 314;
EXEC dbo.usp_GetCustomerOrderSummary @CustomerId = 1024;
GO
