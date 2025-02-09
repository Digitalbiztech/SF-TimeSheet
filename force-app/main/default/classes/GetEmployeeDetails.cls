public with sharing class GetEmployeeDetails {
	@AuraEnabled
    public static dbt__Employee__c getEmployee(Id recID){
        return[SELECT id,Name, Client_Manager__r.Name, Client_Manager_email__c, 
                (SELECT Id, dbt__Employee__r.Name, dbt__Project_Name__c 
                    FROM dbt__Project_Employees__r) 
                FROM dbt__Employee__c where id = :recID Limit 1];
    }
}