/**
 * @file dashboardContributionChart.js
 * @description LWC for displaying a matrix chart visualization of timesheet data
 */

import { LightningElement, api, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import ChartJS from '@salesforce/resourceUrl/jsChart';
import jsChartMatrix from '@salesforce/resourceUrl/jsChartMatrix';
import { getChartData } from 'c/dashboardSharedData';
import USER_ID from '@salesforce/user/Id';

// LMS imports for handling user selection
import { subscribe, MessageContext } from 'lightning/messageService';
import SELECTED_USER_CHANNEL from '@salesforce/messageChannel/SelectedUserChannel__c';

export default class dashboardContributionChart extends LightningElement {
    @track chartData;

    // Chart configuration
    chart;
    isChartJsInitialized = false;
    year = new Date().getFullYear(); // Default to current year

    // LMS configuration
    @wire(MessageContext)
    messageContext;

    subscription = null;
    selectedUserId = USER_ID; // Initialize with current user's ID

    /**
     * @description Lifecycle hook when component is inserted into the DOM
     */
    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    /**
     * @description Subscribes to LMS channel for user selection updates
     */
    subscribeToMessageChannel() {
        if (this.subscription) {
            return;
        }
        this.subscription = subscribe(
            this.messageContext,
            SELECTED_USER_CHANNEL,
            (message) => this.handleMessage(message)
        );
    }

    /**
     * @description Handles incoming LMS messages
     * @param {Object} message - Message containing selected user ID
     */
    handleMessage(message) {
        this.selectedUserId = message.selectedUserId;
        this.initializeChart();
    }

    /**
     * @description Lifecycle hook when component is rendered
     */
    renderedCallback() {
        if (this.isChartJsInitialized) {
            return;
        }
        this.isChartJsInitialized = true;

        // Load required Chart.js libraries
        loadScript(this, ChartJS)
            .then(() => loadScript(this, jsChartMatrix))
            .then(() => this.initializeChart())
            .catch(error => {
                console.log('Error loading Script');
            });
    }

    /**
     * @description Initializes the chart with data for selected user
     */
    initializeChart() {
        if (this.selectedUserId) {
            getChartData(this.selectedUserId)
                .then(data => {
                    this.chartData = data;
                    this.showChart();
                })
                .catch(error => {
                    console.log('Error getting chart data');
                });
        }
    }

    /**
     * @description Renders or updates the chart visualization
     */
    showChart() {
        const ctx = this.template.querySelector('canvas').getContext('2d');
        
        // Handle no data scenario
        if(this.chartData == 0) {
            this.template.querySelector('.slds-m-around_medium').style.display = 'none';
            return;
        }
        this.template.querySelector('.slds-m-around_medium').style.removeProperty('display');

        // Prepare data for the chart
        const graphdata = this.prepareGraphData();

        // Update existing chart or create new one
        if(this.chart){
            this.chart.data.datasets[0].data = graphdata;
            this.chart.update();
        }
        else{
            // Chart configuration object
            this.chart = new Chart(ctx, {
                type: 'matrix',
                data: {
                    datasets: [{
                        label: 'Contributions',
                        data: graphdata,
                        backgroundColor: (context) => {
                            const value = context.dataset.data[context.dataIndex].v;
                            const alpha = value === 0 ? 0.1 
                                        : value < 4 ? 0.3 
                                        : value < 7 ? 0.6 
                                        : value < 10 ? 0.9 
                                        : 1;
                            return `rgba(101, 129, 71, ${alpha})`;
                        },
                        borderColor: (context) => {
                            const value = context.dataset.data[context.dataIndex].v;
                            const alpha = value === 0 ? 0.1 
                                        : value < 4 ? 0.3 
                                        : value < 7 ? 0.6 
                                        : value < 10 ? 0.9 
                                        : 1;
                            return `rgba(101, 129, 71, ${alpha * 0.7})`;
                        },
                        borderWidth: 1,
                        width: (context) => {
                            const area = context.chart.chartArea;
                            return area ? (area.right - area.left) / 53 - 2 : 0;
                        },
                        height: (context) => {
                            const area = context.chart.chartArea;
                            return area ? (area.bottom - area.top) / 7 - 2 : 0;
                        }
                    }]
                },
                options: {
                    animation: { duration: 0 },
                    aspectRatio: 5,
                    plugins: {
                        legend: { display: false },
                        tooltip: {
                            enabled: true,
                            displayColors: false,
                            callbacks: {
                                title: () => '',
                                label: (context) => {
                                    const v = context.dataset.data[context.dataIndex];
                                    return [`Date: ${v.d}`, `Duration: ${v.v}`];
                                }
                            }
                        }
                    },
                    scales: {
                        y: {
                            type: 'linear',
                            offset: true,
                            min: 1,
                            max: 7,
                            position: 'left',
                            ticks: {
                                stepSize: 1,
                                maxRotation: 0,
                                autoSkip: true,
                                callback: value => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1],
                                font: { size: 11 }
                            },
                            grid: { display: false, drawBorder: false, tickLength: 0 }
                        },
                        x: {
                            type: 'linear',
                            position: 'bottom',
                            offset: true,
                            min: 1,
                            max: 53,
                            ticks: {
                                stepSize: 1,
                                maxRotation: 0,
                                autoSkip: true,
                                callback: (value) => {
                                    return new Date(this.year, 0, 1 + (value - 1) * 7)
                                        .toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
                                },
                                font: { size: 11 }
                            },
                            grid: { display: false, drawBorder: false, tickLength: 0 }
                        }
                    },
                    layout: { padding: { top: 10 } }
                }
            });
        }
    }

    /**
     * @description Prepares data for the matrix chart visualization
     * @returns {Array} Formatted data points for the chart
     */
    prepareGraphData() {
        const { dayItems } = this.chartData;

        // Filter data for current year
        const dataItems = dayItems.filter(item => {
            const itemYear = new Date(item.day).getFullYear();
            return itemYear === this.year;
        });

        const dateToDuration = {};
        dataItems.forEach(item => {
            dateToDuration[item.day] = item.duration;
        });

        // Setup date range
        const startDate = new Date(this.year, 0, 1);
        const endDate = new Date(this.year, 11, 31);
        let firstMonday = null;

        /**
         * @description Calculates week number based on Monday
         */
        const getMondayBasedWeekNumber = (date) => {
            const jan1 = new Date(date.getFullYear(), 0, 1);
            const jan1Day = jan1.getDay();

            if (!firstMonday) {
                firstMonday = jan1Day === 1 ? jan1 : new Date(jan1.getTime() + ((8 - jan1Day) % 7) * 86400000);
            }

            return Math.floor((date - firstMonday) / 604800000) + 1;
        };

        // Generate data points
        const graphdata = [];
        for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
            const dateKey = d.toDateString();
            const duration = dateToDuration[dateKey] || 0;
            const weekNumber = getMondayBasedWeekNumber(new Date(d));
            let dayOfWeek = d.getDay();
            dayOfWeek = dayOfWeek === 0 ? 7 : dayOfWeek;

            graphdata.push({
                x: weekNumber,
                y: dayOfWeek,
                d: dateKey,
                v: duration
            });
        }

        return graphdata;
    }
}