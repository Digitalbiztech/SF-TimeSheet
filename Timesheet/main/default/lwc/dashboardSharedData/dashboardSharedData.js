/**
 * @file dashboardSharedData.js
 * @description Service for handling dashboard timesheet data processing and caching
 */

import getDashboardTimesheetLineItemsDetails from "@salesforce/apex/GetDashboardTimesheetLineItems.getDashboardTimesheetLineItemsDetails";

// Cache storage for optimizing repeated requests
let cachedData = {};  // Stores processed data per user_id
let fetchPromises = {};  // Stores ongoing fetch promises per user_id

/**
 * @description Fetches and processes chart data for a given user ID
 * @param {String} user_id - The user ID to fetch data for
 * @returns {Promise<Object|Number>} Processed chart data or 0 if no data
 */
export async function getChartData(user_id) {

    // Return cached data if available
    if (cachedData[user_id]) {
        return cachedData[user_id];
    }

    // Prevent duplicate API calls for the same user_id
    if (!fetchPromises[user_id]) {
        fetchPromises[user_id] = getDashboardTimesheetLineItemsDetails({userID: user_id })
            .then((data) => {

                let processedData;

                // Handle empty data case
                if(data.length==0) {
                    processedData = 0;
                } else {
                    processedData = processData(data);
                }

                // Cache the processed data
                cachedData[user_id] = processedData;
                return processedData;
            })
            .catch((error) => {
                // Clear failed promise from cache
                fetchPromises[user_id] = null;
                throw error;
            });
    }

    return fetchPromises[user_id];
}

/**
 * @description Processes raw timesheet data into structured format
 * @param {Array} abc - Raw timesheet data array
 * @returns {Object} Processed data with year, month, week, and day aggregations
 */
function processData(abc) {
    // Main data storage structures
    const years_months = new Map();
    const weeks = new Map();

    /**
     * @description Helper function to safely get or initialize Map entries
     * @param {Map} map - Target map
     * @param {*} key - Map key
     * @param {*} defaultValue - Default value if key doesn't exist
     */
    const getOrSet = (map, key, defaultValue) => {
        if (!map.has(key)) {
        map.set(key, defaultValue);
        }
        return map.get(key);
    };

    // Time constants
    const millisecondsInWeek = 604800000; // 7 days in milliseconds
    
    // Get reference date for week calculations
    const minDate = new Date(abc[abc.length - 1].Date__c);
    const startOfFirstWeek = getMonday(minDate);  

    /**
     * @description Gets Monday date for a given date
     * @param {Date} date - Input date
     * @returns {Date} Monday date
     */
    function getMonday(date) {  
        date.setDate(date.getDate() - (date.getDay() || 7) + 1);  
        return date.setHours(0, 0, 0, 0), date;  
    }

    /**
     * @description Generates formatted date range string for a week
     * @param {Number} weekNumber - Week number
     * @returns {String} Formatted date range
     */
    function getStartAndEndDate(weekNumber) {
        const startDate = new Date(startOfFirstWeek.getTime() + (weekNumber - 1) * millisecondsInWeek);
        const endDate = new Date(startDate.getTime() + 518400000); // 6 days in ms

        startDate.setHours(0, 0, 0, 0);
        endDate.setHours(23, 59, 59, 999);

        return `${startDate.toDateString()} - ${endDate.toDateString()}`;
    }

    // Process each timesheet entry
    abc.forEach(({ Type__c, Date__c, Name, duration }) => {
        // Extract date components
        const date = new Date(Date__c);
        const year = date.getFullYear();
        const month = date.toLocaleString('default', { month: 'short' }).toLowerCase();
        const day = date.toDateString();
        const week = Math.floor((getMonday(date) - startOfFirstWeek) / millisecondsInWeek) + 1;

        // Initialize or get year data
        const yearData = getOrSet(years_months, year, {
            months: new Map(),
            projects: new Map(),
            duration: 0,
            attendance: 0,
            absence: 0,
        });

        // Initialize or get month data
        const monthData = getOrSet(yearData.months, month, {
            projects: new Map(),
            duration: 0,
            attendance: 0,
            absence: 0,
        });

        // Initialize or get week data
        const weekData = getOrSet(weeks, week, {
            dates: new Map(),
            projects: new Map(),
            duration: 0,
            attendance: 0,
            absence: 0,
        });

        // Initialize or get day data
        const dayData = getOrSet(weekData.dates, day, {
            projects: new Map(),
            duration: 0,
            attendance: 0,
            absence: 0,
        });

        // Update duration totals
        dayData.duration += duration;
        weekData.duration += duration;
        monthData.duration += duration;
        yearData.duration += duration;

        // Process attendance entries
        if (Type__c === "Attendance") {
            // Update attendance totals
            dayData.attendance += duration;
            weekData.attendance += duration;
            monthData.attendance += duration;
            yearData.attendance += duration;

            // Update project-specific durations
            dayData.projects.set(Name, (dayData.projects.get(Name) || 0) + duration);
            weekData.projects.set(Name, (weekData.projects.get(Name) || 0) + duration);
            monthData.projects.set(Name, (monthData.projects.get(Name) || 0) + duration);
            yearData.projects.set(Name, (yearData.projects.get(Name) || 0) + duration);
        } 
        // Process absence entries
        else if (Type__c === "Absence") {
            dayData.absence += duration;
            weekData.absence += duration;
            monthData.absence += duration;
            yearData.absence += duration;
        }
    });

    // Prepare result arrays
    const yearItems = [];
    const monthItems = [];
    const weekItems = [];
    const dayItems = [];

    // Format year and month data
    years_months.forEach((yearData, yearKey) => {
        yearItems.push({
            year: yearKey,
            projects: yearData.projects,
            attendance: yearData.attendance,
            absence: yearData.absence,
            duration: yearData.duration
        });

        yearData.months.forEach((monthData, monthKey) => {
            monthItems.push({
                year: yearKey,
                month: monthKey,
                projects: monthData.projects,
                attendance: monthData.attendance,
                absence: monthData.absence,
                duration: monthData.duration
            });
        });
    });

    // Format week and day data
    weeks.forEach((weekData, weekKey) => {
        const week = {
            week: weekKey,
            projects: weekData.projects,
            attendance: weekData.attendance,
            absence: weekData.absence,
            duration: weekData.duration,
            dates: []
        };
        
        weekData.dates.forEach((dayData, dayKey) => {
            dayItems.push({
                week: weekKey,
                day: dayKey,
                projects: dayData.projects,
                attendance: dayData.attendance,
                absence: dayData.absence,
                duration: dayData.duration
            });
            week.dates.push(dayItems[dayItems.length-1]);
        });

        weekItems.push(week);
    });

    // Return processed data structure
    return { yearItems, monthItems, weekItems, dayItems, getStartAndEndDate};
}