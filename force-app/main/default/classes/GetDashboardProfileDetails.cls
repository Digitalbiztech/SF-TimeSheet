/**
 * @description Class to retrieve dashboard profile details including employee and timesheet information
 * @author Ayan
 */
public with sharing class GetDashboardProfileDetails {
    
    /**
     * @description Retrieves employee details and timesheet summary for dashboard display
     * @param userID The ID of the user to fetch profile details for
     * @return Map<String, Object> Contains employee details and timesheet summary
     * @throws AuraHandledException if insufficient permissions or other errors occur
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getEmployeeDetails(Id userID) {
        try {
            // For testing userId is '005fK000000xxC9QAI'
            // userID = Id.valueOf('005fK000000xxC9QAI');
            
            Map<String, Object> resultData = new Map<String, Object>();
            
            // Fetch Employee Details
            Employee__c employeeRecord = getEmployeeRecord(userID);
            populateEmployeeDetails(resultData, employeeRecord);
            
            // Fetch Timesheet Hours Summary
            AggregateResult timesheetSummary = getTimesheetSummary(userID);
            populateTimesheetSummary(resultData, timesheetSummary);
            
            return resultData;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @description Retrieves employee record with related project information
     * @param userID The ID of the user
     * @return Employee__c Employee record with related data
     */
    private static Employee__c getEmployeeRecord(Id userID) {
        return [
            SELECT Id, Name, Client_Manager__r.Name, Client_Manager_email__c,Email__c,Hire_Date__c,Last_Working_Date__c,No_of_Vacations_Taken__c,Phone_Number__c,
                (SELECT Project_Name__c FROM Project_Employees__r)
            FROM Employee__c
            WHERE User__c = :userID
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }
    
    /**
     * @description Retrieves timesheet summary aggregated data
     * @param userID The ID of the user
     * @return AggregateResult Aggregated timesheet data
     */
    private static AggregateResult getTimesheetSummary(Id userID) {
        return [
            SELECT 
                SUM(Billable_Hours__c) TotalBillableHours, 
                SUM(Non_Billable_Hours__c) TotalNonBillableHours, 
                SUM(Absence_Hours__c) TotalAbsenceHours, 
                SUM(Total_Hours__c) TotalHours
            FROM Timesheet__c
            WHERE 
                Employee__c IN (SELECT id FROM Employee__c WHERE User__c = :userID)
                AND
                Start_Date__c = THIS_YEAR
            WITH SECURITY_ENFORCED
        ];
    }
    
    /**
     * @description Populates employee details in the result map
     * @param resultData Map to store the results
     * @param emp Employee record to process
     */
    private static void populateEmployeeDetails(Map<String, Object> resultData, Employee__c emp) {
        // Basic Information
        resultData.put('Name', emp.Name);
        resultData.put('ClientManager', emp.Client_Manager__r?.Name);
        resultData.put('ClientManagerEmail', emp.Client_Manager_email__c);

        // Additional fields from query
        resultData.put('Email', emp.Email__c);
        resultData.put('HireDate', emp.Hire_Date__c);
        resultData.put('LastWorkingDate', emp.Last_Working_Date__c);
        resultData.put('VacationsTaken', emp.No_of_Vacations_Taken__c);
        resultData.put('PhoneNumber', emp.Phone_Number__c);
        
        // Project information
        List<String> projectNames = new List<String>();
        if (emp.Project_Employees__r != null) {
            for (Project_Employee__c proj : emp.Project_Employees__r) {
                if (proj.Project_Name__c != null) {
                    projectNames.add(proj.Project_Name__c);
                }
            }
        }
        resultData.put('Projects', projectNames.isEmpty() ? 'No Projects Assigned' : String.join(projectNames, ', '));
    }
    
    /**
     * @description Populates timesheet summary in the result map
     * @param resultData Map to store the results
     * @param hours AggregateResult containing timesheet summary
     */
    private static void populateTimesheetSummary(Map<String, Object> resultData, AggregateResult hours) {
        resultData.put('TotalBillableHours', (Decimal) hours.get('TotalBillableHours'));
        resultData.put('TotalNonBillableHours', (Decimal) hours.get('TotalNonBillableHours'));
        resultData.put('TotalAbsenceHours', (Decimal) hours.get('TotalAbsenceHours'));
        resultData.put('TotalHours', (Decimal) hours.get('TotalHours'));
    }
}