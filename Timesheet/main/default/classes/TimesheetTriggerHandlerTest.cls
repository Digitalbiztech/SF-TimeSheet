@isTest
public class TimesheetTriggerHandlerTest {
    
  	public static void updateEmployeeIdTest(){
        Timesheet__c timesheet = new Timesheet__c();
        timesheet.Name = 'Timesheet for'+System.today()+' - '+System.today()+6;
        timesheet.Start_Date__c = System.today();
        timesheet.End_Date__c = System.today()+6;
    }
}