public class TimsheetController {
    @AuraEnabled(cacheable=true)
    public static List<ProcessInstanceWorkItemTimesheetInfo> getProcessInstanceWorkItem(Id userID){
        List<ProcessInstanceWorkItemTimesheetInfo> listOfObject = new List<ProcessInstanceWorkItemTimesheetInfo>();
        List<Timesheet__c> timesheets = new List<Timesheet__c>();
        if(Timesheet__c.SObjectType.getDescribe().isAccessible() &&
            Schema.SObjectType.Timesheet__c.fields.Id.isAccessible() &&
            Schema.SObjectType.Timesheet__c.fields.Name.isAccessible() &&
            Employee__c.SObjectType.getDescribe().isAccessible() &&
            Schema.SObjectType.Employee__c.fields.Name.isAccessible()){
            timesheets = [
                SELECT
                Id,
                Name,
                Employee__r.Name
                FROM Timesheet__c
                WHERE Status__c = 'Submitted'
                WITH SECURITY_ENFORCED
            ];

            List<ProcessInstance> processInstanceRecords = getProcessInstance(timesheets);

            Map<Id, ProcessInstance> processInstancesMap = new Map<Id, ProcessInstance>();
            List<Id> processInstanceIds = new List<Id>();

            for (ProcessInstance processInstanceRecord : processInstanceRecords) {
                processInstancesMap.put(processInstanceRecord.TargetObjectId, processInstanceRecord);
                processInstanceIds.add(processInstanceRecord.Id);
            }

            Map<Id, ProcessInstanceWorkitem> processInstanceWorkitemsMap = getProcessInstanceWorkitemsMap(processInstanceIds, userID);

            for (Timesheet__c timesheet : timesheets) {
                ProcessInstance processInstanceRecord = processInstancesMap.get(timesheet.Id);
                ProcessInstanceWorkitem processInstanceWorkitem = processInstanceWorkitemsMap.get(processInstanceRecord.Id);
                if(processInstanceRecord != null && processInstanceWorkitem != null){
                    ProcessInstanceWorkItemTimesheetInfo obj = new ProcessInstanceWorkItemTimesheetInfo();
                    obj.setTimeSheetName(timesheet.Name);
                    obj.setEmployeeName(timesheet.Employee__r.Name);
                    obj.setProcessInstanceWorkItemId(processInstanceWorkitem.Id);
                    listOfObject.add(obj);
                }
            }
        } else{
            throw new AuraHandledException('You do not have access, please contact System Admin');
        }
        return listOfObject;
    }

    private static List<ProcessInstance> getProcessInstance(List<Timesheet__c> timesheets){
        Set<Id> timesheetIds = new Set<Id>();
        List<ProcessInstance> processInstanceRecords = new List<ProcessInstance>();
        for (Timesheet__c timesheet : timesheets) {
            timesheetIds.add(timesheet.Id);
        }
        processInstanceRecords = [
            SELECT 
            Id,
            TargetObjectId
            FROM ProcessInstance 
            WHERE Status = 'Pending' AND TargetObjectId =:timesheetIds
            WITH SECURITY_ENFORCED
        ];
        return processInstanceRecords;
    }

    private static Map<Id, ProcessInstanceWorkitem> getProcessInstanceWorkitemsMap(List<Id> processInstanceIds, Id userID){
        List<ProcessInstanceWorkitem> ProcessInstanceWorkItems = new List<ProcessInstanceWorkitem>();
        ProcessInstanceWorkItems = [
                    SELECT
                    Id,
                    ActorId,
                    OriginalActorId,
                    ProcessInstanceId
                    FROM ProcessInstanceWorkitem
                    WHERE OriginalActorId = :userID AND ProcessInstanceId =:processInstanceIds
        ];
        Map<Id, ProcessInstanceWorkitem> processInstanceWorkitemsMap = new Map<Id, ProcessInstanceWorkitem>();
        for (ProcessInstanceWorkitem processInstanceWorkitem : ProcessInstanceWorkItems) {
            processInstanceWorkitemsMap.put(processInstanceWorkitem.ProcessInstanceId, processInstanceWorkitem);
        }
        return processInstanceWorkitemsMap;
    }
}