public with sharing class GetTimesheet {
    @AuraEnabled
	public static dbt__Timesheet__c getTimesheetRecords(Id recID){
		dbt__Timesheet__c Timesheet = [SELECT dbt__Employee__r.Name, dbt__Start_Date__c, dbt__End_Date__c,  dbt__Employee__r.Client_Manager__r.Name, dbt__Employee__r.Client_Manager_email__c, dbt__Billable_Hours__c, dbt__Non_Billable_Hours__c, dbt__Total_Hours__c, (SELECT dbt__Duration__c, dbt__Type__c, dbt__Date__c FROM dbt__Timesheets__r) FROM dbt__Timesheet__c WHERE Id = :recID] ;
		return Timesheet;
	}
}