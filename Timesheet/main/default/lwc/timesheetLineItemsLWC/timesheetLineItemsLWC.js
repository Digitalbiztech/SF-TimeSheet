import { LightningElement, track, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import updateTimesheetLineItems from '@salesforce/apex/TimesheetLineItemLwcController.updateTimesheetLineItems';
import getProjects from '@salesforce/apex/TimesheetLineItemLwcController.getProjects';
import getEmployee from '@salesforce/apex/TimesheetLineItemLwcController.getEmployee';
import getTimesheetLineItems from '@salesforce/apex/TimesheetLineItemLwcController.getTimesheetLineItems';

import START_DATE from '@salesforce/schema/Timesheet__c.Start_Date__c';
import END_DATE from '@salesforce/schema/Timesheet__c.End_Date__c';

const fields = [START_DATE, END_DATE];

export default class TimesheetLineItemsLWC extends LightningElement {

    @track timeSheetLineItems = [];
  copyOfTimesheetLineItems = [];
  wiredLineItems;
  error;
  itemsToDelete = [];
  optionArray = [];
  empId;
  empName;
  projectId;
  @api recordId;

  @wire(getTimesheetLineItems, { timesheetId: '$recordId'})
  wiredTimesheetLineItems(result){
    console.log('In wire method');
      this.wiredLineItems = result;
      if(result.data){
        this.handleData(result.data)
      }else if (result.error){
          this.error = result.error;
      }
  }

  @wire(getRecord, { recordId: '$recordId', fields })
  timesheet;

  get startDate() {
    console.log('In startDate method');
      return getFieldValue(this.timesheet.data, START_DATE);
  }

  get endDate() {
    console.log('In endDate method');
      return getFieldValue(this.timesheet.data, END_DATE);
  }

  get options(){
    console.log('In options method');
    return this.optionArray;
  }

  getEmployeeId() {
    console.log('In getEmployeeId method');
    getEmployee({ timesheetrecordId: this.recordId })
      .then(result => {
        console.log('In then Result of getEmployeeId');
        this.empId = result.Id;
        this.empName = result.Name;
        this.getProjectValues(result.Id);
      })
      .catch(error => {
        console.error(error);
      });
  }

  getProjectValues(empIDFromMethod){
    console.log('In getProjectValues method');
    getProjects({empId:empIDFromMethod}).then((result) => {
      let arr = [];
      for (let i = 0; i < result.length; i++) {
        arr.push({
          label: result[i].Project__r.Name,
          value: result[i].Project__c
        });
      }
      this.optionArray = arr;
    })
  }
  
  connectedCallback() {
    console.log('In connectedCallback method');
    this.getEmployeeId();
  }

  createEmptyRow(items) {
    console.log('In createEmptyRow method');
    let timesheetLineItem = {};
    console.log('The length of items is : '+items.length);
    if (items.length > 0) {
      console.log('if items length is greater than 0');
      timesheetLineItem.index =
      items[items.length-1].index + 1;
    } else {
      console.log('else of items length greater than zero');
      timesheetLineItem.index = 1;
    }
    timesheetLineItem.Type__c = 'Attendance';
    timesheetLineItem.Timesheet__c = this.recordId;
    timesheetLineItem.Date__c = new Date().toISOString().split('T')[0];
    timesheetLineItem.Project__c = null;
    timesheetLineItem.Activity__c = null;
    timesheetLineItem.Absence_Category__c = null;
    timesheetLineItem.Duration__c = null;
    timesheetLineItem.Description__c = null;
    timesheetLineItem.isAttendance = true;
    timesheetLineItem.isAbsence = false;
    this.timeSheetLineItems.push(timesheetLineItem);
  }

  addNewRow() {
    console.log('In addNewRow method');
    this.createEmptyRow(this.timeSheetLineItems);
  }

  update() {
    console.log('In update method');

    updateTimesheetLineItems({
      timesheetLineItems: this.timeSheetLineItems, idsToDelete: this.itemsToDelete
    }).then(() => {
      let event = new ShowToastEvent({
        title: 'Success',
        message: 'Successfully Updated',
        variant: 'success',
        mode: 'dismissible'
      });
        this.dispatchEvent(event);
      }).catch((error) => {
        console.log(error);
        let errorMessage = error.body.pageErrors[0].message;
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error',
            message: errorMessage,
            variant: 'error',
            mode: 'dismissible'
          })
        );
      });
      this.itemsToDelete = [];
      console.log('items to delete has been emptied');
  }

  handleChange(event) {
    console.log('In handleChange method');
    let index = event.target.dataset.id;
    let field = event.target.name;
    let value = event.target.value;
    for (let i = 0; i < this.timeSheetLineItems.length; i++) {
      if (this.timeSheetLineItems[i].index === parseInt(index)) {
        this.timeSheetLineItems[i][field] = value;
      }
    }
    for (let i = 0; i < this.timeSheetLineItems.length; i++) {
      if (this.timeSheetLineItems[i].Type__c === "Absence") {
        this.timeSheetLineItems[i].isAbsence = true;
        this.timeSheetLineItems[i].isAttendance = false;
        this.timeSheetLineItems[i].Project__c = null;
        this.timeSheetLineItems[i].Activity__c = null;
      }else if(this.timeSheetLineItems[i].Type__c === "Attendance"){
        this.timeSheetLineItems[i].isAbsence = false;
        this.timeSheetLineItems[i].isAttendance = true;
        this.timeSheetLineItems[i].Absence_Category__c = null;
      }
    }
  }

  handleCancel(){
    location.reload();
  }

  handleData(data){
    console.log('In handleData method');
    console.log(JSON.stringify(data));
    console.log('The lenght of the data is : '+data.length);
    if(data.length <=0){
      console.log('The data length is zero');
      this.createEmptyRow(this.timeSheetLineItems);
    }else if(data.length > 0){
      console.log('The data length is greater than zero');
      let items = [];
      for(let i=0; i<data.length; i++){
        let timesheetLineItem = {};
        timesheetLineItem.index = i+1;
        timesheetLineItem.Id = data[i].Id;
        timesheetLineItem.Type__c = data[i].Type__c;
        timesheetLineItem.Timesheet__c = data[i].Timesheet__c;
        timesheetLineItem.Date__c = data[i].Date__c;
        timesheetLineItem.Project__c = data[i].Project__c;
        timesheetLineItem.Activity__c = data[i].Activity__c;
        timesheetLineItem.Absence_Category__c = data[i].Absence_Category__c;
        timesheetLineItem.Duration__c = data[i].Duration__c;
        timesheetLineItem.Description__c = data[i].Description__c;
        if(timesheetLineItem.Type__c === "Attendance"){
          timesheetLineItem.isAttendance = true;
          timesheetLineItem.isAbsence = false;
        }else if(timesheetLineItem.Type__c === "Absence"){
          timesheetLineItem.isAttendance = false;
          timesheetLineItem.isAbsence = true;
        }
        items.push(timesheetLineItem);
      }
      this.timeSheetLineItems = items;
      this.copyOfTimesheetLineItems = items;
      this.error = undefined;
    }
  }

  deleteItem(event){
    console.log('In deleteItem method');
    let toBeDeletedRowIndex = event.target.dataset.id;
    let timeSheetLineItems = [];
    for(let i = 0; i < this.timeSheetLineItems.length; i++) {
        let tempRecord = Object.assign({}, this.timeSheetLineItems[i]); //cloning object
        delete tempRecord.isAbsence;
        delete tempRecord.isAttendance;
        if(tempRecord.index != toBeDeletedRowIndex) {
          timeSheetLineItems.push(tempRecord);
        }else{
          this.itemsToDelete.push(tempRecord.Id);
        }
    }
    for(let i = 0; i < timeSheetLineItems.length; i++) {
      timeSheetLineItems[i].index = i + 1;
    }
    this.timeSheetLineItems = timeSheetLineItems;
  }
}