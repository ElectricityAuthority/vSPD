*=====================================================================================
* Name:                 vSPDSolveDPS_2.gms
* Function:             Included code for the pivot analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
* Note:                 This code will be included to the end of 6b in vSPDSolve
*                       to revised initialised data according to demand scenario
*=====================================================================================


* The code below is used to set
* bus deficit generation <= total bus load (positive) for simulation run
    DEFICITBUSGENERATION.up(currTP,b)
        $ ( sum[ NodeBus(currTP,n,b), NodeBusAllocationFactor(currTP,n,b)
                                    * NodeDemand(currTP,n) ] > 0 )
        = sum[ NodeBus(currTP,n,b)
             , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n) ] ;

    DEFICITBUSGENERATION.fx(currTP,b)
        $ ( sum[ NodeBus(currTP,n,b), NodeBusAllocationFactor(currTP,n,b)
                                    * NodeDemand(currTP,n) ] <= 0 )
        = 0 ;
* The code to set bus deficit generation end




