
--10
SELECT *
FROM dbo.Payoff_c p
WHERE p.Offer__c IS NULL



DECLARE @OwnerID NVARCHAR(18)

SELECT @OwnerID = ID
FROM dbo.[User]
WHERE Alias = 'dwadmin'

SELECT 
       X10_Month_Approval_Amount__c= NULL, 
       X11_Month_Approval_Amount__c= NULL,
       X12_Month_Approval_Amount__c= NULL,
       X13_Month_Approval_Amount__c= NULL,
       X14_Month_Approval_Amount__c= NULL,
       X15_Month_Approval_Amount__c= NULL, 
       X4_Month_Approval_Amount__c= NULL, 
       X5_Month_Approval_Amount__c= NULL, 
       X6_Month_Approval_Amount__c= NULL,
       X7_Month_Approval_Amount__c= NULL,
       X8_Month_Approval_Amount__c= NULL, 
       X9_Month_Approval_Amount__c= NULL,
       a.Application__c,
       Current_Offer__c = NULL,
       Daily_Payment_Approved__c= CASE WHEN p.Name ='MLP' THEN 0 ELSE 1 END ,
       Impact_Factor__c= NULL,
       Lender__c,
       Max_Approval_Amount__c,
       Max_Term__c,
       Monthly_Payment_Approved__c= CASE WHEN p.Name ='MLP' THEN 1 ELSE 0 END,
      -- CAST(Offer_Generated__c AS SMALLDATETIME) AS Offer_Generated__c,
       Offer_Generation_Status__c = CAST('Offer Generated' AS nvarchar(50)),
       Offer_Status__c = CAST(CASE WHEN a.Application_Status__c = 'Withdrawn' THEN 'Withdrawn'
                              WHEN A.Application_Status__c = 'Approved' THEN 'Approved'
                              ELSE 'Recommended' END AS nvarchar(50)),
       a.Product__c,
       Type__c = CAST('Manual' AS NVARCHAR(50)) ,
       ISNULL(Weekly_Payment_Approved__c, 0) AS Weekly_Payment_Approved__c,
       OwnerId = @OwnerID,
       IsDeleted= 0,

       Offer_Generated__c =CAST(CAST(Offer_Generated__c AS date) AS NVARCHAR(10))+ 'T'+  CAST(CONVERT(TIME(0),Offer_Generated__c) AS NVARCHAR(10))
--SELECT Distinct  Application_Status__c
FROM Phoenix.[Application] a 
LEFT JOIN Phoenix.Product p ON p.DealID = a.DealId
LEFT JOIN Phoenix.Offer o ON a.DealId = o.DealID
WHERE a.Account__c IS NOT null
AND a.Application__c IS NOT NULL
AND a.Application_Status__c <>  'Declined'


SELECT *
FROM Phoenix.Offer
WHERE dealID = 497363


SELECT p.ID, p.Application__c, a.Offer__c
FROM dbo.Payoff_c p
JOIN dbo.Application_c a ON p.Application__c = a.ID
WHERE p.Offer__c IS NULL
--AND a.Offer__c IS NOT NULL


SELECT *
FROM dbo.Application_c
WHERE ID IN ('a045200000Ar7P6AAJ', 'a045200000Ar887AAB')



SELECT Application__c AS ID, ID AS Offer__c
FROM dbo.Offer_c a
WHERE a.Application__c IN (
'a045200000Ar887AAB',
'a045200000Ar7P6AAJ',
'a045200000ArFeqAAF',
'a045200000ArFemAAF',
'a045200000ArFehAAF',
'a045200000ArFenAAF',
'a045200000ArFefAAF',
'a045200000ArFesAAF',
'a045200000ArG1jAAF',
'a045200000ArG1hAAF'
)

SELECT 


SELECT *
FROM dbo.Payoff_c
WHERE ID = 'a0I52000005u1ScEAI'


SELECT *
FROM [UW].[IntergrationApplicationLog] a
WHERE a.Application__c IN (
'a045200000Ar887AAB',
'a045200000Ar7P6AAJ',
'a045200000ArFeqAAF',
'a045200000ArFemAAF',
'a045200000ArFehAAF',
'a045200000ArFenAAF',
'a045200000ArFefAAF',
'a045200000ArFesAAF',
'a045200000ArG1jAAF',
'a045200000ArG1hAAF'


)



a045200000Ar887AAB



UPDATE ial 
SET Offer__c = ap.ID
--SELECT ial.*
FROM dbo.Offer_c ap
JOIN  [UW].[IntergrationApplicationLog] ial ON ISNULL(ap.Application__c,'') = ial.Application__c
AND ISNULL(ap.Product__c,'') = ial.Product__c


DECLARE @OwnerID NVARCHAR(18)

SELECT @OwnerID = ID
FROM dbo.[User]
WHERE Alias = 'dwadmin'

SELECT  Amount__c, 
        a.Application__c,
        Bank_Account_Name__c, 
        Bank_Account_Number__c, 
        Bank_Routing_Number__c, 
        Name_of_Recipient__c, 
        a.Offer__c,
        Payment_Method__c, 
        Payoff_Type__c= 'Third Party Payoff',
        OwnerId = @OwnerID
FROM Phoenix.Payoff p
JOIN [UW].[IntergrationApplicationLog] a ON CAST(p.DealID as NVARCHAR(18)) = a.OpptyID
WHERE a.Account__c IS NOT NULL
AND a.Application__c IS NOT NULL

;WITH cte_AppDups AS (
    SELECT External_Application_ID__c, 
           External_Application_ID_Source__c, 
           COUNT(DISTINCT ID) countOfDups,
           MAX(ID) AS MaxID
    FROM [UW_Salesforce].[dbo].[Application_c] a
    WHERE  External_Application_ID_Source__c IS NOT NULL
    AND ISNULL(External_Application_ID_Source__c, '') IN (
    'National Funding Salesforce Opportuntiy',
    'Phoenix Deal'
    )
   -- AND a.External_Application_ID__c = '006340000135ChjAAE'
    GROUP BY External_Application_ID__c, External_Application_ID_Source__c
)
SELECT ac.ID, ac.External_Application_ID__c, 
           ac.External_Application_ID_Source__c
FROM [UW_Salesforce].[dbo].[Application_c] ac
JOIN cte_AppDups ad ON ad.External_Application_ID__c = ac.External_Application_ID__c
AND ad.External_Application_ID_Source__c = ac.External_Application_ID_Source__c
AND ID <> ad.MaxID



 


SELECT ID,
 --      Application_Status__c,
       Offer__c = NULL

       SELECT *
FROM [UW_Salesforce].[dbo].[Application_c]
WHERE Application_Status__c = 'Declined'
AND Offer__c IS NOT null
AND ID = 'a045200000ArG1hAAF'

SELECT o.Id
FROM [UW_Salesforce].[dbo].[Application_c] a
JOIN UW_Salesforce.dbo.Offer_c o ON o.Application__c = a.id
WHERE Application_Status__c = 'Declined'



SELECT *
FROM [UW_Salesforce].[dbo].[Application_c]
WHERE  ID = 'a045200000ArG1hAAF'


; WITH cte_offerDups AS (

SELECT Application__c, MIN(ID) AS ID, COUNT(1) dups
FROM [UW_Salesforce].[dbo].[Offer_c]
WHERE Application__c IS NOT NULL
AND OwnerId =  '00552000009rzyAAAQ'
AND Application__c  = 'a045200000ArG1hAAF'
GROUP BY Application__c
HAVING COUNT(1) > 1

)
SELECT distinct ID
FROM cte_offerDups



SELECT *
FROM dbo.Application_c
WHERE Id = 'a045200000Aqzr0AAB'

SELECT *
FROM dbo.[User]
WHERE ID = '00552000009rzyAAAQ'


SELECT *
FROM Phoenix.Offer
WHERE DealID = 86106

SELECT *
FROM NF.[Application]
WHERE OpptyID = '0062T00001G59mTQAR'
