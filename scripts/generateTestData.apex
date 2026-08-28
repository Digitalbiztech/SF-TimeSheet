Id userId = UserInfo.getUserId();

// 1. Get or create current user's Employee
List<Employee__c> currEmps = [SELECT Id FROM Employee__c WHERE User__c = :userId LIMIT 1];
Employee__c currentEmployee;
if (currEmps.isEmpty()) {
    currentEmployee = new Employee__c(
        Name = 'Manager User',
        First_Name__c = 'Manager',
        Last_Name__c = 'User',
        Active__c = true,
        User__c = userId
    );
    insert currentEmployee;
} else {
    currentEmployee = currEmps[0];
}

// 2. Create 3 subordinates
List<Employee__c> subordinates = new List<Employee__c>();
for (Integer i = 1; i <= 3; i++) {
    subordinates.add(new Employee__c(
        Name = 'Subordinate ' + i + ' ' + Math.abs(Crypto.getRandomInteger()),
        First_Name__c = 'Subordinate',
        Last_Name__c = 'Test ' + i,
        Active__c = true,
        Manager__c = userId
    ));
}
insert subordinates;

// 3. Ensure we have projects
List<Project__c> projects = [SELECT Id FROM Project__c WHERE Active__c = true LIMIT 3];
while (projects.size() < 3) {
    Project__c p = new Project__c(Name='Test Proj ' + projects.size(), Active__c=true, Billable__c='Yes');
    insert p;
    projects.add(p);
}

// 4. Create Timesheets for last 6 weeks
Date todayDate = Date.today();
Date startOfThisWeek = todayDate.toStartOfWeek().addDays(1); // Assuming Monday start

List<Timesheet__c> allTimesheets = new List<Timesheet__c>();
for (Employee__c emp : subordinates) {
    for (Integer i = 0; i < 6; i++) {
        Date tsStart = startOfThisWeek.addDays(-7 * (i + 1));
        Date tsEnd = tsStart.addDays(6);
        allTimesheets.add(new Timesheet__c(
            Employee__c = emp.Id,
            Start_Date__c = tsStart,
            End_Date__c = tsEnd,
            Status__c = 'Submitted',
            Manager__c = userId
        ));
    }
}
insert allTimesheets;

// 5. Create Line Items
List<Timesheet_Line_Item__c> allItems = new List<Timesheet_Line_Item__c>();
for (Timesheet__c ts : allTimesheets) {
    for (Integer day = 0; day < 7; day++) {
        Date currentDate = ts.Start_Date__c.addDays(day);
        
        // Let's make weekends Absence (Holiday) and weekdays Attendance
        // In Apex: 1 = Sun, 2 = Mon ... 7 = Sat if using Math.mod
        // Actually since tsStart is Monday, day 5 is Sat, day 6 is Sun.
        if (day == 5 || day == 6) {
            allItems.add(new Timesheet_Line_Item__c(
                Timesheet__c = ts.Id,
                Employee__c = ts.Employee__c,
                Date__c = currentDate,
                Type__c = 'Absence',
                Absence_Category__c = 'Holiday',
                Duration__c = 0,
                Description__c = 'Weekend holiday'
            ));
        } else {
            // Weekday: Create 2 Attendance records for different projects, 4 hours each
            allItems.add(new Timesheet_Line_Item__c(
                Timesheet__c = ts.Id,
                Employee__c = ts.Employee__c,
                Project__c = projects[0].Id,
                Activity__c = 'Development-Coding',
                Type__c = 'Attendance',
                Billable__c = 'Yes',
                Date__c = currentDate,
                Duration__c = 4,
                Description__c = 'Morning work'
            ));
            
            // Randomly sometimes make it an Absence (Sick Leave) instead of second half
            if (Math.mod(currentDate.day(), 5) == 0) { // arbitrary condition for variety
                allItems.add(new Timesheet_Line_Item__c(
                    Timesheet__c = ts.Id,
                    Employee__c = ts.Employee__c,
                    Date__c = currentDate,
                    Type__c = 'Absence',
                    Absence_Category__c = 'Sick Leave',
                    Duration__c = 4,
                    Description__c = 'Felt sick afternoon'
                ));
            } else {
                allItems.add(new Timesheet_Line_Item__c(
                    Timesheet__c = ts.Id,
                    Employee__c = ts.Employee__c,
                    Project__c = projects[1].Id,
                    Activity__c = 'Development-Testing',
                    Type__c = 'Attendance',
                    Billable__c = 'Yes',
                    Date__c = currentDate,
                    Duration__c = 4,
                    Description__c = 'Afternoon work'
                ));
            }
        }
    }
}
insert allItems;

System.debug('Successfully generated ' + subordinates.size() + ' employees, ' + allTimesheets.size() + ' timesheets, ' + allItems.size() + ' line items.');
