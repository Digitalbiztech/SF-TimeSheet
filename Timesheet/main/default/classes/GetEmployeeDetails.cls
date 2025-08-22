/**
 * @description Class to retrieve detailed employee information including related project assignments
 * @author Ayan
 */
public with sharing class GetEmployeeDetails {

    public static Boolean hasField(String sObjectApiName, String fieldApiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(sObjectApiName)) return false;
        Schema.DescribeSObjectResult d = gd.get(sObjectApiName).getDescribe();
        Map<String, Schema.SObjectField> fields = d.fields.getMap();
        return fields.containsKey(fieldApiName);
    }

    // Returns true if parent SObject has a child relationship with the given relationship name (e.g. 'Project_Employees__r')
    public static Boolean hasChildRelationship(String parentSObjectApiName, String childRelationshipName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(parentSObjectApiName)) return false;
        Schema.DescribeSObjectResult d = gd.get(parentSObjectApiName).getDescribe();
        for (Schema.ChildRelationship cr : d.getChildRelationships()) {
            String rel = cr.getRelationshipName();
            if (rel != null && rel.equalsIgnoreCase(childRelationshipName)) return true;
        }
        return false;
    }
    
    // Returns true if a field is a reference and references the specified target sObject (target like 'User' or 'Contact' or 'Project_Employee__c')
    public static Boolean isReferenceTo(String sObjectApiName, String fieldApiName, String targetSObjectApiName) {
        if (!hasField(sObjectApiName, fieldApiName)) return false;
        Schema.DescribeFieldResult fr = Schema.getGlobalDescribe()
            .get(sObjectApiName).getDescribe()
            .fields.getMap().get(fieldApiName).getDescribe();
        if (fr.getType() != Schema.DisplayType.Reference) return false;
        for (String ref : fr.getReferenceTo()) {
            if (ref.equalsIgnoreCase(targetSObjectApiName)) return true;
        }
        return false;
    }
    
    // Optional: return field label (null if not present)
    public static String getFieldLabel(String sObjectApiName, String fieldApiName) {
        if (!hasField(sObjectApiName, fieldApiName)) return null;
        return Schema.getGlobalDescribe()
            .get(sObjectApiName).getDescribe()
            .fields.getMap().get(fieldApiName).getDescribe().getLabel();
    }
    
    /**
     * @description Retrieves employee record with related project employee information
     * @param recID The ID of the employee record to fetch
     * @return Employee__c Employee record with related project assignments
     * @throws AuraHandledException if insufficient permissions or other errors occur
     */
    @AuraEnabled
    public static Employee__c getEmployee(Id recID) {
        try {
            if (recID == null) {
                throw new AuraHandledException('Employee ID cannot be null');
            }



if (!Schema.getGlobalDescribe().containsKey('Employee__c')) {
    throw new AuraHandledException('Employee__c does not exist');
}
if (!hasField('Employee__c','Name')) {
    throw new AuraHandledException('Field Name is missing on Employee__c');
}
if (!hasField('Employee__c','Client_Manager__c')) {
    throw new AuraHandledException('Field Client_Manager__c is missing on Employee__c');
}
if (!hasField('Employee__c','Client_Manager_email__c')) {
    throw new AuraHandledException('Field Client_Manager_email__c is missing on Employee__c');
}
if (!hasChildRelationship('Employee__c','Project_Employees__r')) {
    throw new AuraHandledException('Child relationship Project_Employees__r is missing on Employee__c');
}
if (!isReferenceTo('Employee__c','Client_Manager__c','User')) {
    throw new AuraHandledException('Client_Manager__c does not reference User');
}
if (!Schema.getGlobalDescribe().containsKey('Project_Employee__c')) {
    throw new AuraHandledException('Project_Employee__c does not exist');
}
if (!hasField('Project_Employee__c','Employee__c')) {
    throw new AuraHandledException('Field Employee__c is missing on Project_Employee__c');
}
if (!hasField('Project_Employee__c','Project_Name__c')) {
    throw new AuraHandledException('Field Project_Name__c is missing on Project_Employee__c');
}
if (getFieldLabel('Employee__c','Client_Manager_email__c') == null) {
    throw new AuraHandledException('Field Client_Manager_email__c is missing or inaccessible on Employee__c');
}



            return [
                SELECT 
                    Id,
                    Name, 
                    Client_Manager__r.Name, 
                    Client_Manager_email__c,
                    (
                        SELECT 
                            Id, 
                            Employee__r.Name, 
                            Project_Name__c 
                        FROM Project_Employees__r
                    )
                FROM Employee__c 
                WHERE Id = :recID
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}