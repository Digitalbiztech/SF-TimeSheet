public class ProcessInstanceWorkItemTimesheetInfo {

    private String timeSheetName;
    private String employeeName;
    private Id  processInstanceWorkItemId;


    @AuraEnabled(cacheable=true)
    public String getTimeSheetName(){
        return timeSheetName;
    }
    public void setTimeSheetName(String newTimeSheetName){
        this.timeSheetName = newTimeSheetName;
    }

    @AuraEnabled(cacheable=true)
    public String getEmployeeName(){
        return employeeName;
    }
    public void setEmployeeName(String newEmployeeName){
        this.employeeName = newEmployeeName;
    }

    @AuraEnabled(cacheable=true)
    public String getProcessInstanceWorkItemId(){
        return processInstanceWorkItemId;
    }
    public void setProcessInstanceWorkItemId(String newProcessInstanceWorkItemId){
        this.processInstanceWorkItemId = newProcessInstanceWorkItemId;
    }
}