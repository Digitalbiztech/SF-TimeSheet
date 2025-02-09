public with sharing class GetDashboardProfileDetails {
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getEmployeeDetails(String employeeId) {
        Map<String, Object> resultData = new Map<String, Object>();

        // Fetch Employee Details
        dbt__Employee__c emp = [
            SELECT Id, Name, Client_Manager__r.Name, Client_Manager_email__c,
                (SELECT dbt__Project_Name__c FROM dbt__Project_Employees__r)
            FROM dbt__Employee__c
            WHERE dbt__User__c = '005fK000000xxC9QAI' // userid
            LIMIT 1
        ];

        system.debug('emp => ' + emp);

        resultData.put('Name', emp.Name);
        resultData.put('ClientManager', emp.Client_Manager__r != null ? emp.Client_Manager__r.Name : null);
        resultData.put('ClientManagerEmail', emp.Client_Manager_email__c);

        List<String> projectNames = new List<String>();
        for (dbt__Project_Employee__c proj : emp.dbt__Project_Employees__r) {
            projectNames.add(proj.dbt__Project_Name__c);
        }
        resultData.put('Projects', String.join(projectNames, ', '));

        // Fetch Timesheet Hours Summary
        AggregateResult hours = [
            SELECT 
                SUM(dbt__Billable_Hours__c) TotalBillableHours, 
                SUM(dbt__Non_Billable_Hours__c) TotalNonBillableHours, 
                SUM(dbt__Absence_Hours__c) TotalAbsenceHours, 
                SUM(dbt__Total_Hours__c) TotalHours
            FROM dbt__Timesheet__c
            WHERE dbt__Employee__c IN (select id from dbt__Employee__c where dbt__User__c = '005fK000000xxC9QAI') // userid
        ];

        System.debug('hours => ' + hours);

        resultData.put('TotalBillableHours', (Decimal) hours.get('TotalBillableHours'));
        resultData.put('TotalNonBillableHours', (Decimal) hours.get('TotalNonBillableHours'));
        resultData.put('TotalAbsenceHours', (Decimal) hours.get('TotalAbsenceHours'));
        resultData.put('TotalHours', (Decimal) hours.get('TotalHours'));

        return resultData;
    }
}

