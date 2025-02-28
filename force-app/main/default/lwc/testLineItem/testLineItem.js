import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getWeeklyTimesheetItems from '@salesforce/apex/WeeklyTimesheetController.getWeeklyTimesheetItems';
import saveWeeklyTimesheet from '@salesforce/apex/WeeklyTimesheetController.saveWeeklyTimesheet';
import getProjects from '@salesforce/apex/WeeklyTimesheetController.getProjects';
import getTimesheet from '@salesforce/apex/WeeklyTimesheetController.getTimesheet';
import getEmployeeTimesheetItems from '@salesforce/apex/WeeklyTimesheetController.getEmployeeTimesheetItems';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import TIMESHEET_LINE_ITEM_OBJECT from '@salesforce/schema/dbt__Timesheet_Line_Item__c';
import ACTIVITY_CATEGORY_FIELD from '@salesforce/schema/dbt__Timesheet_Line_Item__c.dbt__Activity__c';
import ABSENCE_CATEGORY_FIELD from '@salesforce/schema/dbt__Timesheet_Line_Item__c.dbt__Absence_Category__c';



export default class TestLineItem extends LightningElement {
    @api recordId;
    @track projectsList = [];
    @track projectOptions = [];
    @track activityOptions= [];
    @track absenceList = [];
    @track absenceOptions = [];

    @track prevTimesheets= [];
    prevTimesheetValue;

    @track projectsTotals = [0, 0, 0, 0, 0, 0, 0];
    @track absenceTotals = [0, 0, 0, 0, 0, 0, 0];
    @track grandTotals = [0, 0, 0, 0, 0, 0, 0];

    TimesheetStartDate='';
    TimeSheetEndDate='';
    EmployeeID='';

    previousRecordIDs;

    wiredTimesheetResult;
    error;

    
    dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    dayList=[];

    // Get object info to retrieve recordTypeId
    @wire(getObjectInfo, { objectApiName: TIMESHEET_LINE_ITEM_OBJECT })
    objectInfo;

    // Fetch picklist values for Activity
    @wire(getPicklistValues, { 
        recordTypeId: '$objectInfo.data.defaultRecordTypeId', 
        fieldApiName: ACTIVITY_CATEGORY_FIELD 
    })
    wiredActivityPicklistValues({ error, data }) {
        if (data) {
            this.activityOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            console.error('Error fetching Activity picklist values:', error);
        }
    }

    // Fetch picklist values for Absence
    @wire(getPicklistValues, { 
        recordTypeId: '$objectInfo.data.defaultRecordTypeId', 
        fieldApiName: ABSENCE_CATEGORY_FIELD 
    })
    wiredAbsencePicklistValues({ error, data }) {
        if (data) {
            this.absenceOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            console.error('Error fetching Absence picklist values:', error);
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    connectedCallback() {
        this.fetchTimesheetData(this.recordId, result => {
            this.wiredTimesheetResult = result;
        });
        this.loadTimesheet();
    }

    fetchTimesheetData(Id, callback) {
        getWeeklyTimesheetItems({ timesheetId: Id })
            .then(result => {
                callback(result);
            })
            .catch(error => {
                console.error(error);
            });
    }

    loadTimesheet() {
        getTimesheet({ timesheetId: this.recordId })
            .then(result => {
                this.EmployeeID = result.dbt__Employee__c;
                this.TimesheetStartDate = result.dbt__Start_Date__c;
                this.TimeSheetEndDate = result.dbt__End_Date__c;
            })
            .then(() => {
                this.createDays();
                this.loadProjects();
                this.loadPrevTimesheets();
            })
            .then(() => {
                this.processTimesheetData(this.wiredTimesheetResult,true);
            })
            .catch(error => {
                this.error = error;
            });
    }

    createDays() {
        let startDate = new Date(this.TimesheetStartDate);

        this.dayList = Array.from({ length: 7 }, (_, i) => {
            
            const tempDate = new Date(startDate);
            tempDate.setDate(tempDate.getDate() + i);
            
            return tempDate.toISOString().split('T')[0];
        });
    }

    loadPrevTimesheets(){
        getEmployeeTimesheetItems({ empId: this.EmployeeID})
            .then(result => {
                this.prevTimesheets = result.map(item => ({
                    label: item.Name,
                    value: item.Id
                }));
            })
            .catch(error => {
                this.error = error;
            });
    }

    loadProjects() {
        getProjects({ empId: this.EmployeeID })
            .then(result => {
                this.projectOptions = result.map(proj => ({
                    label: proj.dbt__Project__r.Name,
                    value: proj.dbt__Project__c
                }));
            })
            .catch(error => {
                this.error = error;
            });
    }

    processTimesheetData(data,includeId) {
        this.projectsList = [];
        this.absenceList = [];

        this.previousRecordIDs = new Set();

        let attendanceData = {};
        let absenceData = {};

        data.forEach(item => {
            const date = new Date(item.dbt__Date__c);
            const dayIndex = date.getDay() === 0 ? 6 : date.getDay() - 1;

            if(includeId){
                this.previousRecordIDs.add(item.Id);
            }

            // Helper to update the date data
            const updateDate = record => {
                record.dates[dayIndex].dur = item.dbt__Duration__c || 0;
                record.dates[dayIndex].desc = item.dbt__Description__c || '';
                record.dates[dayIndex].id = includeId ? item.Id : '';
                record.dates[dayIndex].isdisable = false;
            };

            if (item.dbt__Type__c === "Attendance") {
                const key = `${item.dbt__Project__c}_${item.dbt__Activity__c}`;
                if (!attendanceData[key]) {
                    attendanceData[key] = {
                        ...this.getBlankData("Attendance"),
                        projectName: item.dbt__Project__c,
                        activityName: item.dbt__Activity__c
                    };
                }
                updateDate(attendanceData[key]);
            } else {
                const key = item.dbt__Absence_Category__c;
                if (!absenceData[key]) {
                    absenceData[key] = {
                        ...this.getBlankData("Absence"),
                        absenceName: item.dbt__Absence_Category__c
                    };
                }
                updateDate(absenceData[key]);
            }
        });

        this.projectsList = Object.values(attendanceData);
        this.absenceList = Object.values(absenceData);

        if(this.projectsList.length === 0) {
            this.addNewProject();
        }

        if(this.absenceList.length === 0) {
            this.addNewAbsence();
        }

        // calculate totals
        this.calculateTotals();

    }

    getBlankData(type) {
        const dates = this.dayNames.map((name, index) => {
            return {
                id: "",
                isdisable: true,
                date: this.dayList[index],
                name,
                dur: 0,
                desc: ""
            };
        });

        if (type === "Attendance") {
            return {
                type: "Attendance",
                projectName: "",
                activityName: "",
                dates
            };
        } else {
            return {
                type: "Absence",
                absenceName: "",
                dates
            };
        }
    }

    handleProjectChange(event) {
        const rowIndex = event.target.dataset.rowIndex;
        const fieldName = event.target.name;
        const newValue = event.target.value;

        // Get the current row
        const currentRow = this.projectsList[rowIndex];

        // Create a temporary copy of the current row to test the change
        const tempRow = { ...this.projectsList[rowIndex] };
        
        // Apply the potential change to the temporary row
        if (fieldName === 'projectName') {
            tempRow.projectName = newValue;
        } else if (fieldName === 'activityName') {
            tempRow.activityName = newValue;
        }

        // Only check for duplicates if both fields have values
        if (tempRow.projectName && tempRow.activityName) {
            // Check if this combination would create a duplicate
            const wouldCreateDuplicate = this.projectsList.some((row, index) => 
                index !== parseInt(rowIndex) && 
                row.projectName === tempRow.projectName && 
                row.activityName === tempRow.activityName
            );

            if (wouldCreateDuplicate) {
                // Show error toast
                this.showToast(
                    'Error', 
                    'A row with the same Project and Activity already exists.', 
                    'error'
                );

                // Revert the change by setting the combobox value back
                event.target.value = currentRow[fieldName];
                return; // Exit without making any changes
            }
        }

       // Apply change since it's valid
        currentRow[fieldName] = newValue;
    }

    handleDurationChange(event) {
        const rowIndex = event.target.dataset.rowIndex;
        const dayIndex = event.target.dataset.dayIndex;
        const value = parseFloat(event.target.value);
        const dataFor = event.target.getAttribute('data-for'); // "project" or "absence"
        
        let list;
        if (dataFor === 'project') {
            list = this.projectsList;
        } else if (dataFor === 'absence') {
            list = this.absenceList;
        }

        if (isNaN(value) || value < 0 || value > 24) {
            this.showToast('Error', "Duration must be a number between 0 and 24", 'error');
            event.target.value = list[rowIndex].dates[dayIndex].dur || 0;
            return;
        }

        list[rowIndex].dates[dayIndex].dur = value;
        list[rowIndex].dates[dayIndex].isdisable = (value === 0);
    }



    handleDeleteRow(event) {
        const rowIndex = parseInt(event.target.dataset.rowIndex);
        const type = event.target.dataset.type;

        try {
            if (type === 'project') {
                // Remove row from projectsList
                this.projectsList = this.projectsList.filter((row, index) => index !== rowIndex);
                
                // If all projects are deleted, you might want to keep at least one empty row
                if (this.projectsList.length === 0) {
                    this.addNewProject();
                }
            } else if (type === 'absence') {
                // Remove row from absenceList
                this.absenceList = this.absenceList.filter((row, index) => index !== rowIndex);
                
                // If all absences are deleted, you might want to keep at least one empty row
                if (this.absenceList.length === 0) {
                    this.addNewAbsence();
                }
            }

            // Show success toast
            this.showToast('Success', 'Row deleted', 'success');
        } catch (error) {
            // Show error toast
            this.showToast('Error', 'Failed to delete row', 'error');
            console.error('Error deleting row:', error);
        }
    }

    handleAbsenceChange(event) {
        const rowIndex = event.target.dataset.rowIndex;
        const newValue = event.target.value;

        // Get the current row's existing value
        const currentRow = this.absenceList[rowIndex];

        // Check if this absence type is already selected in another row
        const isDuplicate = this.absenceList.some((row, index) => 
            index !== parseInt(rowIndex) && row.absenceName === newValue
        );

        if (isDuplicate) {
            // Show error toast if duplicate found
            this.showToast(
                'Error',
                'This absence type is already selected in another row',
                'error'
            );

            // Reset the value in UI to its previous state
            event.target.value = currentRow.absenceName;
            return;
        }

        // Update the absence name if no duplicate
        currentRow.absenceName = newValue;
    }

    addNewProject() {
        const newProject = this.getBlankData("Attendance");
        this.projectsList.push(newProject);
    }

    addNewAbsence() {
        const newAbsence = this.getBlankData("Absence");
        this.absenceList.push(newAbsence);
    }

    handleSave(){
        let upsertList = [];
        let currentRecordIDs = new Set();

        try {
            this.projectsList.forEach(project => {
                project.dates.forEach(day => {
                    if (day.dur > 0) {
                        if(project.projectName === '' || project.activityName === ''){
                            this.showToast('Error', "Project name or Activity name cannot be blank", 'error');
                            return;
                        }
                        currentRecordIDs.add(day.id);
                        upsertList.push({
                            dbt__Timesheet__c: this.timesheetId,
                            ID: day.id,
                            dbt__Project__c: project.projectName,
                            dbt__Activity__c: project.activityName,
                            dbt__Duration__c: day.dur,
                            dbt__Description__c: day.desc,
                            dbt__Date__c: day.date
                        });
                    }
                });
            });

            this.absenceList.forEach(absence => {
                absence.dates.forEach(day => {
                    if (day.dur > 0) {
                        if(absence.absenceName === ''){
                            this.showToast('Error', "Absence name cannot be blank", 'error');
                            return;
                        }
                        currentRecordIDs.add(day.id);
                        upsertList.push({
                            dbt__Timesheet__c: this.timesheetId,
                            ID: day.id,
                            dbt__Absence_Category__c: absence.absenceName,
                            dbt__Duration__c: day.dur,
                            dbt__Description__c: day.desc,
                            dbt__Date__c: day.date
                        });
                    }
                });
            });

            const deleteList = [...this.previousRecordIDs].filter(id => !currentRecordIDs.has(id));

        } catch (error) {
            this.showToast('Error', error, 'error');
        }

        console.log("upsertList", JSON.stringify(upsertList));
        console.log("deleteList", JSON.stringify(deleteList));

    }

    calculateTotals() {
        // Reset totals
        this.projectsTotals = [0, 0, 0, 0, 0, 0, 0];
        this.absenceTotals = [0, 0, 0, 0, 0, 0, 0];
        this.grandTotals = [0, 0, 0, 0, 0, 0, 0];

        // Calculate Projects totals
        this.projectsList.forEach(project => {
            project.dates.forEach((day, index) => {
                const duration = parseFloat(day.dur) || 0;
                this.projectsTotals[index] += duration;
            });
        });

        // Calculate Absence totals
        this.absenceList.forEach(absence => {
            absence.dates.forEach((day, index) => {
                const duration = parseFloat(day.dur) || 0;
                this.absenceTotals[index] += duration;
            });
        });

        // Calculate Grand totals
        this.projectsTotals.forEach((total, index) => {
            this.grandTotals[index] = total + this.absenceTotals[index];
        });
    }

    prevTimesheet(event) {
        this.prevTimesheetValue=event.detail.value;
    }

    handleCopy(){
        if(this.prevTimesheetValue != undefined){
            console.log(this.prevTimesheetValue);
            this.fetchTimesheetData(this.prevTimesheetValue, result => {
                this.processTimesheetData(result,false);
                this.showToast('Success', 'Timesheet copied successfully', 'success');
            });
        }
    }

    handleCancel() {
        this.processTimesheetData(this.wiredTimesheetResult,true);
    }
}

