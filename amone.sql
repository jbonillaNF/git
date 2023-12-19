USE [Analytics_WS]
GO
-- Test a change to the file for GIT
-- Test a change to the file for GIT

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[usp_AmOneDailyFile]
AS 
/*****************************************************************************
Name:		 dbo.usp_AmOneDailyFile

Purpose:	This stored procedure used to AmOne Daily SSIS package
              
Called by:	SSIS package n 

Author:		Julio A. Bonilla
Date:		2023-05-30

*******************************************************************************
       CHANGE HISTORY
*******************************************************************************
Date		Author			 Description
--------	-------------	 ---------------------------------------------------
2023-05-30  Julio Bonilla	 Initial Creation

******************************************************************************/
-------------------------------------------------------------------------------
--  Declarations
-------------------------------------------------------------------------------
SET NOCOUNT ON 
--SET FMTONLY OFF
SET TRAN ISOLATION LEVEL READ UNCOMMITTED
BEGIN TRY

DECLARE	 @RowCount              int		= 0
		,@ErrMsg				nvarchar(max)	= 'N/A'
		,@Status			    varchar(10)		= 'Success'
        ,@PackageID int	-- This identifies the record in the audit.Package table 
		,@Description  varchar(50)	 = NULL


-------------------------------------------------------------------------------
--  Annual Revenue History
-------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#tempAnnualRevenueHistory') IS NOT NULL
    DROP TABLE #tempAnnualRevenueHistory

SELECT lh.CreatedDate,
       lh.LeadId,
       lh.OldValue AS AnnualRevenue,
       ROW_NUMBER() OVER (PARTITION BY lh.LeadId ORDER BY lh.CreatedDate) AS RN
INTO #tempAnnualRevenueHistory
FROM Salesforce_Repl.dbo.LeadHistory lh
WHERE lh.Field = 'AnnualRevenue'
      AND lh.IsDeleted = 'false'

-------------------------------------------------------------------------------
--  NF Leads
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#tempNFLeads', 'U') IS NOT NULL
    DROP TABLE #tempNFLeads;
SELECT DISTINCT
       'National Funding' AS Brand,
       rsc.Id AS ReferralSummaryId,
       rsc.Referral_Source_Name__c AS LeadAggregator,
       rsc.Lead__c AS LeadId,
       rsc.Referral_DateTime__c AS ReferralDate,
       er.Attribute_Value__c AS ExternalRequestId,
              CASE WHEN rsc.Referral_Source_Name__c LIKE 'Fundera%' THEN
                CASE WHEN cmp.Attribute_Value__c = '39728897-d054-46b2-aa3a-665692a41e9b' THEN
                         'Segment 1'
                    WHEN cmp.Attribute_Value__c = 'e2c1c570-1889-4c4e-b864-17566c35fe3a' THEN
                        'Segment 2'
                    WHEN cmp.Attribute_Value__c = '3a4b4514-3f79-4fb4-a192-92a4f2018ff7' THEN
                        'Segment 3'
                    WHEN cmp.Attribute_Value__c = '33aeae85-cf92-48ab-bc00-015fe1697c80' THEN
                        'Segment 4'
                    WHEN cmp.Attribute_Value__c = '566f1942-647c-4bf6-be38-0b862179024c' THEN
                        'Segment 3.1'
                        
                END
               WHEN rsc.Referral_Source_Name__c = 'Seek - Experian' THEN '1' 
               WHEN rsc.Referral_Source_Name__c = 'AmOne'  THEN 'AmOne1'
          ELSE
               cmp.Attribute_Value__c
       END AS CampaignId,
       Case when rsc.Referral_Source_Name__c = 'Seek - Experian' then '7013n0000019SpIAAU' 
            when rsc.Referral_Source_Name__c = 'AmOne'  THEN '1234'
            else  cmp.Attribute_Value__c end as AttributeValue,
       cpl.Attribute_Value__c AS CPL,
       l.ConvertedAccountId,
       l.Activation_Date__c,
       COALESCE(lrjc.Annual_Revenue__c, tarh.AnnualRevenue, l.AnnualRevenue) AS AnnualRevenue,
       CAST(l.Description AS VARCHAR(MAX)) AS Description,
       DATEDIFF(MONTH, COALESCE(lrjc.Date_Established__c, l.Date_Established__c), rsc.Referral_DateTime__c) AS TIBMonths,
       COALESCE(lrjc.Date_Established__c, l.Date_Established__c) AS DateEstablished,
       COALESCE(lrjc.State__c, l.State) AS LeadState,
       CASE WHEN lrjc.Credit_Score__c LIKE 'Excellent%' THEN
                'Excellent'
           WHEN lrjc.Credit_Score__c LIKE 'Good%' THEN
               'Good'
           WHEN lrjc.Credit_Score__c LIKE 'Fair%' THEN
               'Fair'
           WHEN lrjc.Credit_Score__c LIKE 'Poor%' THEN
               'Poor'
           WHEN l.Description LIKE '%Estimated Credit: Poor%'
                OR l.Description LIKE '%EstimatedCredit: Poor%'
                OR l.Description LIKE '%EstimatedCredit:Poor%'
                OR l.Description LIKE '%639%or%less%' THEN
               'Poor'
           WHEN l.Description LIKE '%Estimated Credit: Fair%'
                OR l.Description LIKE '%EstimatedCredit: Fair%'
                OR l.Description LIKE '%EstimatedCredit:Fair%'
                OR l.Description LIKE '%640%to%679%' THEN
               'Fair'
           WHEN l.Description LIKE '%Estimated Credit: Good%'
                OR l.Description LIKE '%EstimatedCredit: Good%'
                OR l.Description LIKE '%EstimatedCredit:Good%'
                OR l.Description LIKE '%680%to%719%' THEN
               'Good'
           WHEN l.Description LIKE '%Estimated Credit: Excellent%'
                OR l.Description LIKE '%EstimatedCredit: Excellent%'
                OR l.Description LIKE '%EstimatedCredit:Excellent%'
                OR l.Description LIKE '%720%to%950%' THEN
               'Excellent'
       END AS CreditScoreBin,
       lrjc.Amount_Requested__c,
       cmp.Attribute_Value__c,
       rsc.Referral_DateTime__c
INTO #tempNFLeads


FROM Salesforce_Repl.dbo.Referral_Summary__c rsc
INNER JOIN Salesforce_Repl.dbo.Referral_Attribute__c er ON er.Referral_Summary__c = rsc.Id
                                                               AND er.Attribute_Name__c = 'ExternalRequestId'
LEFT JOIN Salesforce_Repl.dbo.Referral_Attribute__c cmp ON cmp.Referral_Summary__c = rsc.Id
                                                               AND cmp.Attribute_Name__c = 'CampaignId'
LEFT JOIN Salesforce_Repl.dbo.Referral_Attribute__c cpl ON cpl.Referral_Summary__c = rsc.Id
                                                               AND cmp.Attribute_Name__c = 'CostPerLead'
INNER JOIN Salesforce_Repl.dbo.[Lead] l ON rsc.Lead__c = l.Id
LEFT JOIN Salesforce_Repl.dbo.Lead_Response_Journal__c lrjc ON lrjc.Lead_Source_Record_Id__c = er.Attribute_Value__c
LEFT JOIN #tempAnnualRevenueHistory tarh ON tarh.LeadId = l.Id
WHERE rsc.Referral_Source_Name__c IN ('AmOne')
AND rsc.Referral_DateTime__c >= '2022-06-01'
--AND rsc.Referral_DateTime__c <  '2022-09-01'





-------------------------------------------------------------------------------
--  QB Leads
-------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#tempQBLeads', 'U') IS NOT NULL
    DROP TABLE #tempQBLeads;
SELECT *
INTO #tempQBLeads
FROM OPENQUERY
     ([SDW-QBRPT-P01],
      'SELECT ''Quick Bridge'' AS Brand,
	   rsc.Lead_Source__c AS LeadAggregator,
       rsc.Lead_Source_Record_Id__c,
	   rsc.Id as ResponseJournalId,
       rsc.CreatedDate as ReferralDate,
	   DATEDIFF(MONTH,rsc.Date_Established__c, rsc.CreatedDate) as TIBMonths,
      CASE 
              WHEN rsc.[Lead_Source__c] LIKE ''Fundera%'' AND rsc.[CreatedDate] >= ''2022-03-23 14:10:00'' 
              THEN
                  CASE WHEN rac.Attribute_Value__c = ''53ebf299-1413-4ce0-9297-41e36bd60adc'' THEN
                        ''Segment 1''
                        WHEN rac.Attribute_Value__c = ''82735830-4069-4a9c-bf43-0821350e4080'' THEN
                        ''Segment 2''
                        WHEN rac.Attribute_Value__c = ''272258c4-1014-4f1d-abcb-a2be925b79f4'' THEN
                        ''Segment 3''
                        WHEN rac.Attribute_Value__c = ''fd8ee27a-198c-406c-9eac-4c4bfa2a94a0'' THEN
                        ''Segment 4''
                       WHEN rac.Attribute_Value__c = ''566f1942-647c-4bf6-be38-0b862179024c'' THEN
                        ''Segment 3.1''  
                     END
            WHEN rsc.[Lead_Source__c] LIKE ''Fundera%''
                AND rsc.[CreatedDate] < ''2022-03-23 14:10:00'' THEN  NULL
            WHEN rsc.Lead_Source__c = ''Seek - Experian'' THEN ''1'' 
            WHEN rsc.Lead_Source__c = ''AmOne''  THEN ''AmOne1''
           ELSE
               rac.Attribute_Value__c
       END AS CampaignId,
        Case when rsc.Lead_Source__c = ''Seek - Experian'' then ''7013n0000019SpIAAU'' 
             when rsc.Lead_Source__c = ''AmOne''  THEN ''1234''
            else  rac.Attribute_Value__c  end as AttributeValue,
       er.Attribute_Value__c AS ExternalRequestId,
       cpl.Attribute_Value__c AS CPL,
       rsc.Lead__c as LeadId,
       l.Activation_Date__c,
       l.ConvertedAccountId,
       COALESCE(rsc.Annual_Revenue__c,l.AnnualRevenue) as AnnualRevenue,
       COALESCE(rsc.Amount_Requested__c,l.Amount_Requested__c) as AmountRequested,
       COALESCE(rsc.Date_Established__c,l.Date_Established__c) as DateEstablished,
       CAST(l.Description AS VARCHAR(MAX)) AS Description,
       CASE WHEN rsc.Credit_Score__c LIKE ''Excellent%'' THEN ''Excellent''
	   WHEN rsc.Credit_Score__c LIKE ''Good%'' THEN ''Good''
	   WHEN rsc.Credit_Score__c LIKE ''Fair%'' THEN ''Fair''
	   WHEN rsc.Credit_Score__c LIKE ''Poor%'' THEN ''Poor''
	   WHEN l.Description LIKE ''%Estimated Credit: Poor%''
                 OR Description LIKE ''%EstimatedCredit: Poor%''
                 OR Description LIKE ''%EstimatedCredit:Poor%''
                 OR Description LIKE ''%639%or%less%'' THEN
                ''Poor''
           WHEN Description LIKE ''%Estimated Credit: Fair%''
                OR Description LIKE ''%EstimatedCredit: Fair%''
                OR Description LIKE ''%EstimatedCredit:Fair%''
                OR Description LIKE ''%640%to%679%'' THEN
               ''Fair''
           WHEN Description LIKE ''%Estimated Credit: Good%''
                OR Description LIKE ''%EstimatedCredit: Good%''
                OR Description LIKE ''%EstimatedCredit:Good%''
                OR Description LIKE ''%680%to%719%'' THEN
               ''Good''
           WHEN Description LIKE ''%Estimated Credit: Excellent%''
                OR Description LIKE ''%EstimatedCredit: Excellent%''
                OR Description LIKE ''%EstimatedCredit:Excellent%''
                OR Description LIKE ''%720%to%950%'' THEN
               ''Excellent''
           ELSE
               ''Not Captured''
       END AS CreditScoreBin,
       COALESCE(rsc.State__c,l.State) as State,
       rac.Attribute_Value__c
FROM SalesforceReplQB.dbo.Lead_Response_Journal__c rsc
    INNER JOIN SalesforceReplQB.dbo.Lead l ON rsc.Lead__c = l.Id
    INNER JOIN SalesforceReplQB.dbo.Referral_Attribute__c er ON er.Lead_Response_Journal__c = rsc.Id
                                                                AND er.Attribute_Name__c = ''ExternalRequestId''
    LEFT JOIN SalesforceReplQB.dbo.Referral_Attribute__c rac ON rac.Lead_Response_Journal__c = rsc.Id
                                                                AND rac.Attribute_Name__c = ''CampaignId''
    LEFT JOIN SalesforceReplQB.dbo.Referral_Attribute__c cpl ON cpl.[Lead_Response_Journal__c] = rsc.Id
                                                                AND cpl.Attribute_Name__c = ''CostPerLead''
WHERE rsc.Lead_Source__c IN ( ''AmOne'') 
AND rsc.CreatedDate >= ''2022-06-01''
') oq

-------------------------------------------------------------------------------
--  AmOne Partner Campaign
-------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#tempPartnerCampaign', 'U') IS NOT NULL
    DROP TABLE #tempPartnerCampaign;

SELECT *
into #tempPartnerCampaign
FROM edw.dbo.PartnerCampaign
where [Partner] IN ('AmOne')


-------------------------------------------------------------------------------
--  Merge QB & NF
-------------------------------------------------------------------------------

----Creates table, #tempLTLeads
IF OBJECT_ID('tempdb..#tempLTLeads', 'U') IS NOT NULL
    DROP TABLE #tempLTLeads;

SELECT DISTINCT l.LeadAggregator,
       l.Brand,
       l.ReferralSummaryId,
       l.ExternalRequestId,
       l.ReferralDate,
       COALESCE(l.AttributeValue, pcr.AttributeValue) as AttributeValue,
       CASE WHEN l.LeadAggregator = 'SmallBusinessLoans.com' THEN
                'SBL'
           ELSE
               COALESCE(l.CampaignId, pcr.Campaign)
       END AS CampaignId,
       CASE WHEN l.LeadAggregator = 'SmallBusinessLoans.com' THEN
                0
            WHEN l.LeadAggregator = 'Seek - Experian' THEN
                0
            WHEN l.LeadAggregator = 'AmOne' THEN
                0
           ELSE
               COALESCE(CAST(l.CPL AS FLOAT),  pcr.CPL)
       END AS CPL,
       l.LeadId,
       l.CreditScoreBin,
       l.Attribute_Value__c,
       l.TIBMonths,
       l.AnnualRevenue,
       CostType =  pcr.costtype,
       pcr.NewInternalPayoutPoints, 
       pcr.RenewalInternalPayoutPoints, 
       pcr.NewExternalPayoutRate, 
       pcr.RenewalExternalPayoutRate


INTO #tempLTLeads
--217
FROM #tempNFLeads l
LEFT JOIN #tempPartnerCampaign pcr on l.LeadAggregator = pcr.[Partner]
AND pcr.Brand = l.Brand
and l.AttributeValue = pcr.AttributeValue
and isNull(l.CreditScoreBin, '') = pcr.CreditRating

and l.AnnualRevenue between pcr.AGSMin and IsNull(pcr.AGSMax, 10000000)
and l.Amount_Requested__c between pcr.LoanAmountMin and IsNull(pcr.LoanAmountMax, 1000000)
and l.TIBMonths between pcr.TIBMonthsMin and IsNull(pcr.TIBMonthsMax, 10000) 
AND l.ReferralDate BETWEEN COALESCE(pcr.StartDate, '1900-01-01')  AND COALESCE(pcr.StopDate,GETDATE())
--WHERE pcr.costtype = 'Revshare'
UNION
SELECT Distinct l.LeadAggregator,
       l.Brand,
       l.ResponseJournalId AS ReferralSummaryId,
       l.ExternalRequestId,
       l.ReferralDate,
       pcr.AttributeValue,
       CASE WHEN l.LeadAggregator = 'SmallBusinessLoans.com' THEN
                'SBL'
           ELSE
               COALESCE(l.CampaignId,  pcr.Campaign)
       END AS CampaignId,
       pcr.CPL,
       l.LeadId,
       l.CreditScoreBin,
       l.Attribute_Value__c,
       l.TIBMonths,
       l.AnnualRevenue,
       CostType =  COALESCE(pcr.CostType ,    'CPL'),
       pcr.NewInternalPayoutPoints, 
       pcr.RenewalInternalPayoutPoints, 
       pcr.NewExternalPayoutRate, 
       pcr.RenewalExternalPayoutRate
    --   SELECT *
FROM #tempQBLeads l
LEFT JOIN #tempPartnerCampaign pcr on l.LeadAggregator = pcr.[Partner]
AND pcr.Brand = l.Brand
and l.Attribute_Value__c = pcr.AttributeValue
and isNull(l.CreditScoreBin, '') = pcr.CreditRating
and l.AnnualRevenue between pcr.AGSMin and IsNull(pcr.AGSMax, 10000000)
and l.AmountRequested between pcr.LoanAmountMin and IsNull(pcr.LoanAmountMax, 1000000)
and l.TIBMonths between pcr.TIBMonthsMin and IsNull(pcr.TIBMonthsMax, 10000) 
AND l.ReferralDate BETWEEN COALESCE(pcr.StartDate, '1900-01-01')  AND COALESCE(pcr.StopDate,GETDATE())
--WHERE pcr.costtype = 'Revshare'

-------------------------------------------------------------------------------
--  QB Deals
-------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#tempQBDeal', 'U') IS NOT NULL
    DROP TABLE #tempQBDeal;
SELECT *
INTO #tempQBDeal
FROM OPENQUERY
     ([10.20.30.64\QBFREPLICATION], 'SELECT d.DealId, d.BLANo, d.FundingDate, d.FundedAmount FROM Phoenix.dbo.Deal d ') oq

IF OBJECT_ID('tempdb..#tempQBSalesforce') IS NOT NULL
    DROP TABLE #tempQBSalesforce

-------------------------------------------------------------------------------
--  Salesforce data
-------------------------------------------------------------------------------
SELECT *
INTO #tempQBSalesforce
FROM OPENQUERY
     ([SDW-QBRPT-P01],
      'SELECT a.Id AS AccountId,
       o.Id AS OppId,
       o.Name AS OppName,
       o.Type AS OppType,
       o.StageName,
       o.Application_Submitted_Date__c,
       o.Approved_Date__c,
       o.Contract_Out_Date__c,
       o.Contract_In_Date__c,
       o.Funded_Date__c,
       o.Funded_Amount__c,
       o.Margin__c,
       fc.Lender_Deal_Id__c,
       a_l.Name AS LenderName,
       CASE
           WHEN F.Lender_Name__c = ''National Funding, Inc.''
                OR
                (
                    F.Lender_Name__c LIKE ''%Quick Bridge%''
                    AND OQPHX.BrokerName LIKE ''%National Funding%''
                ) THEN ''CrossBrand''
           WHEN F.Lender_Name__c LIKE ''%Quick Bridge%''
                OR F.Lender_Name__c IS NULL THEN ''OBS''
           WHEN F.Lender_Name__c NOT LIKE ''%Quick Bridge%'' THEN ''External''
           ELSE NULL
       END AS OBSType 
FROM SalesforceReplQB.dbo.Account a
LEFT JOIN SalesforceReplQB.dbo.Opportunity o ON a.Id = o.AccountId
LEFT JOIN SalesforceReplQB.dbo.Funding__c fc ON fc.Opportunity__c = o.Id AND fc.Lender_Name__c LIKE ''Quick Bridge%''
LEFT JOIN SalesforceReplQB.dbo.Account a_l ON o.Lender__c = a_l.Id
LEFT JOIN	(
					SELECT	Id as FundingID,
                            Opportunity__c, 
                            Approved_Date__c, 
                            Approved_Amount__c, 
                            Lender_Name__c,
                            F.Lender_Deal_Id__c,
                         	CASE WHEN F.Lender_Name__c = ''Quick Bridge Funding'' THEN CONVERT(INT, F.Lender_Deal_Id__c)
                  				 ELSE NULL
			                     END AS PhoenixDealId,
                            rn = ROW_NUMBER() OVER(PARTITION BY Opportunity__c ORDER BY CreatedDate DESC)
					FROM	SalesforceReplQB.dbo.Funding__c f
					WHERE 1=1
                	 AND Approved_Date__c IS NOT NULL
                     and Status__c = ''Approved''
					) f ON o.Id = f.Opportunity__c AND f.rn = 1
LEFT JOIN OPENQUERY
              ([10.20.30.64\QBFREPLICATION], ''
		    SELECT
			    D.DealId
		       ,B.BrokerName
               ,dt.DealType
		    FROM Phoenix.dbo.Deal AS D
            JOIN Phoenix.dbo.DealType dt ON dt.DealTypeId = d.DealTypeId
			JOIN Phoenix.dbo.vwDealBroker_Transpose AS DBT ON DBT.DealId = D.DealId

			JOIN Phoenix.dbo.[Broker] AS B ON B.Id = DBT.Broker1 WHERE B.BrokerName is NOT NULL

			'') AS OQPHX
        ON OQPHX.DealId = F.PhoenixDealId
    
    
    ') oq
---------------------------------------------------------------------------------------- END OF INITIAL SQL QUERY ------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#tempQBSalesforce') IS NOT NULL
    DROP TABLE #AmOneStageReport


SELECT t.Brand, t.ExternalRequestId, OppName, LeadAggregator, ResponseDate, FundDate, CreditSubDate, ApprovalDate,StageName, FundedPrin 
into #AmOneStageReport
FROM
(   SELECT ltl.Brand,
           ltl.LeadAggregator,
           'NF' + l.LeadId AS LeadId,
          -- l.Activation_Date__c AS ActivationDate, 
           l.Activation_Date__c as ResponseDate,
           'NF' + l.ConvertedAccountId AS AccountId,
           ltl.ExternalRequestId,
           ltl.ReferralDate,
           l.AnnualRevenue,
           l.[Description],
           l.DateEstablished,
           l.LeadState,
           ROW_NUMBER() OVER (PARTITION BY ltl.ExternalRequestId
                              ORDER BY ltl.ReferralDate,
                                       o.Credit_Sub_Date__c) AS SpendRN,
           CASE WHEN o.OppId IS NOT NULL THEN
                    ROW_NUMBER() OVER (PARTITION BY o.OppId
                                       ORDER BY ltl.ReferralDate DESC,
                                                o.Credit_Sub_Date__c)
           END AS OpportunityRN,
           'NF' + o.OppId AS OppId,
           o.Merchant_Number__c AS LoanNumber,
           o.OppName,
           o.OppType,
           o.StageName,
           o.NewOrRenewal,
           o.Credit_Sub_Date__c AS CreditSubDate,
           o.Fund_Date__c AS FundDate,
           o.APPROVAL_DATE__c AS ApprovalDate,
           o.Lender_Account_Name AS LenderAccountName,
           o.Actual_Amt_Offered__c AS ActualAmountOffered,
           o.Actual_Sales_Margin AS ActualSalesMargin,
           l.Amount_Requested__c AS AmountRequested,
           CASE WHEN  o.Fund_Date__c is not null AND o.StageName = 'Funded' AND o.OppType = 'NEW' THEN o.Actual_Amt_Offered__c
                WHEN  o.Fund_Date__c is not null AND o.StageName = 'Funded' AND o.OppType =  'CONCURRENT' THEN o.Actual_Amt_Offered__c
                WHEN  o.Fund_Date__c is not null AND o.StageName = 'Funded' AND o.OppType = 'RENEWAL' THEN o.Actual_Amt_Offered__c
                WHEN  o.Fund_Date__c is not null AND o.StageName = 'Funded' AND o.OppType =  'RENEWAL CONCURRENT' THEN o.Actual_Amt_Offered__c
                ELSE 0 END AS FundedPrin,
           DATEDIFF(MONTH, l.ReferralDate, o.Fund_Date__c) AS Funded_Aging,
           CASE WHEN DATEDIFF(MONTH, l.ReferralDate, o.Fund_Date__c) >= 24 THEN
                    24
               ELSE
                   DATEDIFF(MONTH, l.ReferralDate, o.Fund_Date__c)
           END AS Funded_Aging_24,
           ltl.CPL,
           ltl.CampaignId,
           l.CreditScoreBin,
           ltl.TIBMonths,
           isNull(ltl.CostType, 'CPL') as CostType,
 
           CampaignLabel = case when ltl.CampaignId = 'SBL' then 'SBL' else  ltl.AttributeValue END,
           CPLFlag = Case when ltl.LeadAggregator <>'SmallBusinessLoans.com' and IsNull(ltl.CPL, 0) = 0 and costType <> 'Revshare' Then 'Yes' ELSE 'No'  END,
           NewInternalPayout = CASE WHEN o.Fund_Date__c is not null and o.NewOrRenewal = 'New' and  o.OBSType in ('OBS', 'CrossBrand') THEN isNull(o.Actual_Amt_Offered__c *  ltl.NewInternalPayoutPoints,0) ELSE 0 END,
           RenewalInternalPayout= CASE WHEN o.Fund_Date__c is not null and o.NewOrRenewal ='Renewal' and o.OBSType in ('OBS', 'CrossBrand') THEN isNull(o.Actual_Amt_Offered__c * ltl.RenewalInternalPayoutPoints,0)ELSE 0 END,
           NewExternalPayout	= CASE WHEN o.Fund_Date__c is not null and o.NewOrRenewal = 'New' and  o.OBSType in ('External') THEN  isNull(o.Actual_Sales_Margin * ltl.NewExternalPayoutRate,0) ELSE 0 END,
           RenewalExternalPayout =CASE WHEN o.Fund_Date__c is not null and o.NewOrRenewal ='Renewal' and o.OBSType in ('External') THEN isNull(o.Actual_Sales_Margin * ltl.RenewalExternalPayoutRate,0) ELSE 0 END
          -- SELECT *
    FROM #tempLTLeads ltl
        LEFT JOIN #tempNFLeads l ON l.LeadId = ltl.LeadId
        LEFT JOIN Analytics_DWH.dbo.Opportunity_All_VW o ON o.AccountId = l.ConvertedAccountId
                                                            AND o.Credit_Sub_Date__c > ltl.ReferralDate
    WHERE ltl.Brand = 'National Funding'
    UNION ALL
    SELECT ltl.Brand,
           ltl.LeadAggregator,
           'QB' + tql.LeadId AS LeadId,
           tql.Activation_Date__c,
           'QB' + tql.ConvertedAccountId AS AccountId,
           ltl.ExternalRequestId,
           ltl.ReferralDate,
           tql.AnnualRevenue,
           tql.[Description],
           tql.DateEstablished,
           tql.State,
           ROW_NUMBER() OVER (PARTITION BY ltl.ExternalRequestId
                              ORDER BY tql.ReferralDate,
                                       tqs.Application_Submitted_Date__c) AS SpendRN,
           CASE WHEN tqs.oppid IS NOT NULL THEN
                    ROW_NUMBER() OVER (PARTITION BY tqs.OppId
                                       ORDER BY ltl.ReferralDate DESC,
                                                tqs.Application_Submitted_Date__c)
           END AS OpportunityRN,
           'QB' + tqs.OppId AS OppId,
           pd.BlaNo AS LoanNumber,
           tqs.OppName,
           tqs.OppType,
           tqs.StageName,
           tqs.oppType,
           tqs.Application_Submitted_Date__c AS CreditSubDate,
           CASE WHEN tqs.lenderName NOT LIKE 'Quick Bridge%' THEN
                     tqs.Funded_Date__c
                ELSE pd.FundingDate END AS FundDate,
           tqs.Approved_Date__c AS ApprovalDate,
           tqs.lenderName AS LenderAccountName,
           CASE WHEN tqs.lenderName NOT LIKE 'Quick Bridge%' THEN
                    tqs.Funded_Amount__c
               ELSE
                   pd.FundedAmount
           END AS ActualAmountOffered,
           tqs.Margin__c AS ActualSalesMargin,
           tql.AmountRequested,
           CASE WHEN  tqs.Funded_Date__c is not null AND tqs.StageName = 'Funded' AND tqs.OppType = 'NEW' THEN tqs.Funded_Amount__c
                WHEN  tqs.Funded_Date__c is not null AND tqs.StageName = 'Funded' AND tqs.OppType = 'CONCURRENT' THEN tqs.Funded_Amount__c
                WHEN  tqs.Funded_Date__c is not null AND tqs.StageName = 'Funded' AND tqs.OppType = 'RENEWAL' THEN tqs.Funded_Amount__c
                WHEN  tqs.Funded_Date__c is not null AND tqs.StageName = 'Funded' AND tqs.OppType = 'RENEWAL CONCURRENT' THEN tqs.Funded_Amount__c
                ELSE 0 END AS FundedPrin,
           DATEDIFF(MONTH, tql.ReferralDate, tqs.Funded_Date__c) AS Funded_Aging,
           CASE WHEN DATEDIFF(MONTH, tql.ReferralDate, tqs.Funded_Date__c) >= 24 THEN
                    24
               ELSE
                   DATEDIFF(MONTH, tql.ReferralDate, tqs.Funded_Date__c)
           END AS Funded_Aging_24,
           isNull(ltl.CPL, 0) AS CPL,
           ltl.CampaignId,
           tql.CreditScoreBin,
           ltl.TIBMonths,
           isNull(ltl.CostType, 'CPL') as CostType,

           CampaignLabel = case when ltl.CampaignId = 'SBL' then 'SBL' else  ltl.AttributeValue END,
           CPLFlag = Case when ltl.LeadAggregator <>'SmallBusinessLoans.com' and IsNull(ltl.CPL, 0) = 0 and costType<> 'Revshare' Then 'Yes' ELSE 'No'  END,
           NewInternalPayout = CASE WHEN tqs.Funded_Date__c is not null and tqs.oppType = 'New' and  tqs.OBSType in ('OBS', 'CrossBrand') THEN isNull(tqs.Funded_Amount__c *  ltl.NewInternalPayoutPoints,0) ELSE 0 END,
           RenewalInternalPayout= CASE WHEN tqs.Funded_Date__c is not null and tqs.oppType ='Renewal' and tqs.OBSType in ('OBS', 'CrossBrand') THEN isNull(tqs.Funded_Amount__c * ltl.RenewalInternalPayoutPoints,0)ELSE 0 END,
           NewExternalPayout	= CASE WHEN tqs.Funded_Date__c is not null and tqs.oppType = 'New' and  tqs.OBSType in ('External') THEN  isNull(tqs.Funded_Amount__c * ltl.NewExternalPayoutRate,0) ELSE 0 END,
           RenewalExternalPayout =CASE WHEN tqs.Funded_Date__c is not null and tqs.oppType ='Renewal' and tqs.OBSType in ('External') THEN isNull(tqs.Funded_Amount__c * ltl.RenewalExternalPayoutRate,0) ELSE 0 END
           --SELECT *
    FROM #tempLTLeads ltl 
    LEFT JOIN #tempQBLeads tql ON tql.Lead_Source_Record_Id__c = ltl.ExternalRequestId
    LEFT JOIN #tempQBSalesforce tqs ON tql.ConvertedAccountId = tqs.AccountId
                                           AND tqs.Application_Submitted_Date__c > ltl.ReferralDate
     LEFT JOIN #tempQBDeal pd ON tqs.Lender_Deal_Id__c = pd.DealId
    WHERE ltl.Brand = 'Quick Bridge'
    ) t



TRUNCATE TABLE dbo.AmOneStageReport
INSERT INTO [dbo].[AmOneStageReport](
Brand, ExternalLeadID, OppName, [Partner], ResponseDate, StageName, FundedPrin, StageChangeDate
           )

SELECT Brand, ExternalRequestId, OppName, LeadAggregator, CONVERT (varchar , cast(ResponseDate as datetime), 120 ) as ResponseDate, StageName, FundedPrin,  CONVERT (varchar , ResponseDate, 120 )  as StageChangeDate
FROM #AmOneStageReport
where Stagename in ('Application Submitted','Approved','Approved - Lease','Approved - MCA','Funded')
and (Cast(ResponseDate as date) = Cast(Getdate()-1   as date)) 
and FundDate is null 
and CreditSubDate is null 
and ApprovalDate is null
UNION
SELECT Brand, ExternalRequestId, OppName, LeadAggregator,  CONVERT (varchar , cast(ResponseDate as datetime), 120 ) , StageName, FundedPrin, CONVERT (varchar , FundDate, 120 )  as StageChangeDate
FROM #AmOneStageReport
WHERE Stagename in ('Application Submitted','Approved','Approved - Lease','Approved - MCA','Funded')
and  Cast(FundDate as date) = Cast(Getdate()-1  as date)
UNION
SELECT Brand, ExternalRequestId, OppName, LeadAggregator,  CONVERT (varchar , cast(ResponseDate as datetime), 120 ) , StageName, FundedPrin, CONVERT (varchar , CreditSubDate, 120 )  as StageChangeDate
FROM #AmOneStageReport
WHERE Stagename in ('Application Submitted','Approved','Approved - Lease','Approved - MCA','Funded')
and Cast(CreditSubDate as date) = Cast(Getdate()-1  as date)
and Cast(ApprovalDate as date) <> Cast(CreditSubDate as date)
UNION
SELECT Brand, ExternalRequestId, OppName, LeadAggregator,  CONVERT (varchar , cast(ResponseDate as datetime), 120 ) , StageName, FundedPrin, CONVERT (varchar , ApprovalDate, 120 ) as StageChangeDate
FROM #AmOneStageReport
WHERE Stagename in ('Application Submitted','Approved','Approved - Lease','Approved - MCA','Funded')
and Cast(ApprovalDate as date) = Cast(Getdate()-1  as date)


END TRY
-------------------------------------------------------------------------------
--  Error Handling
-------------------------------------------------------------------------------
BEGIN CATCH
		
		DECLARE 
		    @ErrorMsg		 NVARCHAR(4000),
			@ErrorNumber     INT,
			@ErrorSeverity   INT,
			@ErrorState      INT,
			@ErrorLine       INT,
			@ErrorProcedure  NVARCHAR(200);


        -- Assign variables to error-handling functions that 
		SELECT 
	        @ErrorNumber = ERROR_NUMBER(),
		    @ErrorSeverity = ERROR_SEVERITY(),
	        @ErrorState = ERROR_STATE(),
			@ErrorLine = ERROR_LINE(),
			@ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-'),
			@ErrorMsg = ERROR_MESSAGE(),
			@Status = 'Failed'

		 -- Building the message string with original error information.
		 SET @ErrMsg = N'Error Number '   + CAST(@ErrorNumber	AS NVARCHAR(50)) + ', '+
						'Error Severity ' + CAST(@ErrorSeverity AS NVARCHAR(50)) + ', '+			
						'Error Line '     + CAST(@ErrorLine AS NVARCHAR(50)) + ', '+
						'Error State'     + CAST(@ErrorState AS NVARCHAR(50)) + ', '+
						'Error Message : ''' + @ErrorMsg + ''''

	    -- Raising an error
	    	IF 	@ErrorNumber < 50000	
		      SELECT	 @ErrorNumber	= @ErrorNumber + 100000000 -- Need to increase number to throw message.
	        --;THROW	 @ErrorNumber, @ErrMsg, 1
		
END CATCH


--;WITH cte_report AS (

--SELECT *, ROW_NUMBER() OVER(PARTITION BY ExternalLeadID ORDER BY StageChangeDate Desc) AS RowID
--FROM dbo.AmOneStageReport

--)
--SELECT *
--FROM cte_report
--WHERE cte_report.RowID = 1