*=====================================================================================
* Name:                 vSPDSolveFTR_4.gms
* Function:             Calculate FTR branch and constraint participation loading
*                       and estimate FTR rental allocation
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     03 June 2021
*=====================================================================================


*=====================================================================================
* 1. Calculate branch and constraint participation loading
*=====================================================================================
Scalar FTRsequentialSolve                   / 0 / ;

* FTR rental - extra sets and parameters declaration ---------------------------
Set
  FTRpattern                  'FTR flow direction'
$include FTRPattern.inc
;
Alias (FTRpattern,ftr) ;

Table
  FTRinjection(ftr,n)         'Maximum injections'
$include FTRinjection.inc
  ;
Parameters
  FTRbranchFlow(ftr,dt,br)    'FTR directed MW flow on each branch for the different time periods'
  FTRbrCstrLHS(ftr,dt,brCstr) 'FTR directed branch constraint value'

* parameters for sequential solve
  injectionFTR(n)         'Nodal generation applied for FTR Model'
  branchFlowFTR(dt,br)    'FTR directed MW flow on each branch for the different time periods'
  brCstrLHSFTR(dt,brCstr) 'FTR directed branch constraint value'

  ;


* FTR model declaration --------------------------------------------------------
Variables
  FTRACBRANCHFLOW(tp,br,ftr)         'MW flow on AC branch for each ftr pattern'
  FTRACNODEANGLE(tp,b,ftr)           'Bus voltage angle for each ftr pattern'
* variables for sequential solve
  ACBRANCHFLOWFTR(tp,br)             'MW flow on AC branch for each ftr pattern'
  ACNODEANGLEFTR(tp,b)               'Bus voltage angle for each ftr pattern'
;

Positive variables
  FTRDEFICITBUSGENERATION(tp,b,ftr)  'Deficit generation at a bus in MW'
  FTRSURPLUSBUSGENERATION(tp,b,ftr)  'Surplus generation at a bus in MW'
* variables for sequential solve
  DEFICITBUSGENERATIONFTR(tp,b)  'Deficit generation at a bus in MW'
  SURPLUSBUSGENERATIONFTR(tp,b)  'Surplus generation at a bus in MW'
;

Equations
  FTRObjectiveFunction            'Objective function of the FTR flow pattern model'
  FTRLinearLoadFlow(tp,br,ftr)    'Equation that describes Kirchhoff"s circuit laws'
  FTRbusEnergyBalance(tp,b,ftr)   'Energy balance at bus level'
* equation for sequential solve
  ObjectiveFunctionFTR            'Objective function of the FTR flow pattern model'
  linearLoadFlowFTR(tp,br)        'Equation that describes Kirchhoff"s circuit laws'
  busEnergyBalanceFTR(tp,b)       'Energy balance at bus level'
;

FTRObjectiveFunction..
  NETBENEFIT
=e=
- sum[ (bus,ftr), deficitBusGenerationPenalty * FTRDEFICITBUSGENERATION(bus,ftr) ]
- sum[ (bus,ftr), surplusBusGenerationPenalty * FTRSURPLUSBUSGENERATION(bus,ftr) ]
  ;

ObjectiveFunctionFTR..
  NETBENEFIT
=e=
- sum[ bus, deficitBusGenerationPenalty * DEFICITBUSGENERATIONFTR(bus) ]
- sum[ bus, surplusBusGenerationPenalty * SURPLUSBUSGENERATIONFTR(bus) ]
  ;

* Kirchoff's law
FTRLinearLoadFlow(branch(tp,br),ftr)..
  FTRACBRANCHFLOW(branch,ftr)
=e=
 sum[ BranchBusDefn(branch,frB,toB)
    , branchSusceptance(branch)
    * (FTRACNODEANGLE(tp,frB,ftr) - FTRACNODEANGLE(tp,toB,ftr))
    ]
  ;

linearLoadFlowFTR(branch(tp,br))..
  ACBRANCHFLOWFTR(branch)
=e=
 sum[ BranchBusDefn(branch,frB,toB)
    , branchSusceptance(branch)
    * (ACNODEANGLEFTR(tp,frB) - ACNODEANGLEFTR(tp,toB))
    ]
  ;

*Energy balance
FTRbusEnergyBalance(bus(tp,b),ftr)..
  sum[ branchBusDefn(branch(tp,br),b,toB), FTRACBRANCHFLOW(branch,ftr) ]
- sum[ branchBusDefn(branch(tp,br),frB,b), FTRACBRANCHFLOW(branch,ftr) ]
=e=
  sum[ NodeBus(tp,n,b)
     , NodeBusAllocationFactor(tp,n,b) * FTRinjection(ftr,n)
     ]
+ FTRDEFICITBUSGENERATION(tp,b,ftr) - FTRSURPLUSBUSGENERATION(tp,b,ftr)
  ;

busEnergyBalanceFTR(bus(tp,b))..
  sum[ branchBusDefn(branch(tp,br),b,toB), ACBRANCHFLOWFTR(branch) ]
- sum[ branchBusDefn(branch(tp,br),frB,b), ACBRANCHFLOWFTR(branch) ]
=e=
  sum[ NodeBus(tp,n,b)
     , NodeBusAllocationFactor(tp,n,b) * injectionFTR(n)
     ]
+ DEFICITBUSGENERATIONFTR(tp,b) - SURPLUSBUSGENERATIONFTR(tp,b)
  ;

Model FTR_Model
  /
  FTRObjectiveFunction
  FTRLinearLoadFlow
  FTRbusEnergyBalance
  / ;

Model FTR_Model_sequential
  /
  ObjectiveFunctionFTR
  linearLoadFlowFTR
  busEnergyBalanceFTR
  / ;


* FTR model solve --------------------------------------------------------------
putclose runlog 'FRT flow calculation started' / ;

* Redefine some network sets
bus(tp,b)            = yes $ i_tradePeriodBus(tp,b) ;
node(tp,n)           = yes $ i_tradePeriodNode(tp,n) ;
referenceNode(node)  = yes $ i_tradePeriodReferenceNode(node);
nodeBus(node,b)      = yes $ i_tradePeriodNodeBus(node,b) ;
busIsland(bus,ild)   = i_tradePeriodBusIsland(bus,ild) ;
nodeIsland(tp,n,ild) = yes $ sum[ bus(tp,b) $ { nodeBus(tp,n,b) and
                                                busIsland(bus,ild) }, 1 ] ;

* Node-bus allocation factor
nodeBusAllocationFactor(tp,n,b) $ { node(tp,n) and bus(tp,b) }
    = i_tradePeriodNodeBusAllocationFactor(tp,n,b) ;

* HVDC must always be modeled as in service
i_tradePeriodBranchCapacity(tp,br)     $ i_TradePeriodHVDCBranch(tp,br) = 9999;
i_tradePeriodBranchOpenStatus(tp,br)   $ i_TradePeriodHVDCBranch(tp,br) = no;
i_TradePeriodBranchDefn(tp,br,frB,toB) $ i_TradePeriodHVDCBranch(tp,br) = no;
i_TradePeriodBranchDefn(tp,br,frB,toB) $ i_tradePeriodHVDCBranch(tp,br)
    = yes$ { sum[ referenceNode(tp,n) $ { nodeBus(tp,n,frB) and
                                          busIsland(tp,frB,'SI') }, 1 ] and
             sum[ referenceNode(tp,n) $ { nodeBus(tp,n,toB) and
                                          busIsland(tp,toB,'NI') }, 1 ]
           };

* Redefine branch sets and data
branch(tp,br) = yes $ { (not i_tradePeriodBranchOpenStatus(tp,br))
                      * i_tradePeriodBranchCapacity(tp,br)
                      * sum[ (b,b1) $ { bus(tp,b) * bus(tp,b1)
                                      * i_tradePeriodBranchDefn(tp,br,b,b1)
                                      }, 1 ] } ;

branchBusDefn(branch,b,b1) = yes $ i_tradePeriodBranchDefn(branch,b,b1) ;
HVDClink(branch)      $ i_tradePeriodHVDCBranch(branch)         = yes ;
ACbranch(branch)      $ ( not HVDClink(branch) )                = yes ;

branchSusceptance(branch(tp,br))
    = sum[ i_branchParameter $ (ord(i_branchParameter) = 2)
         , i_tradePeriodBranchParameter(branch,i_branchParameter) ]
         * [ 100$(not i_useBusNetworkModel(tp))
           - 100$(    i_useBusNetworkModel(tp)) ];

branchSusceptance(HVDClink(tp,br)) = 10000$(not i_useBusNetworkModel(tp))
                                   - 10000$(    i_useBusNetworkModel(tp)) ;

* Redefine branch constraint data for the current trading period
branchConstraint(tp,brCstr)
    $ sum[ br $ { i_tradePeriodBranchConstraintFactors(tp,brCstr,br) and
                  branch(tp,br) }, 1 ] = yes ;

branchConstraintFactors(branchConstraint,br)
    = i_tradePeriodBranchConstraintFactors(branchConstraint,br) ;

branchConstraintSense(branchConstraint)
    = sum[ i_ConstraintRHS $ (ord(i_ConstraintRHS) = 1),
           i_tradePeriodBranchConstraintRHS(branchConstraint,i_ConstraintRHS)
         ] ;

branchConstraintLimit(branchConstraint)
    = sum[ i_ConstraintRHS$(ord(i_ConstraintRHS) = 2),
         i_tradePeriodBranchConstraintRHS(branchConstraint,i_ConstraintRHS)
         ] ;


if(sequentialSolve,
  putclose runlog 'Vectorisation is switched OFF for FTR' /;

  loop(ftr,
    option clear = NETBENEFIT ;
    option clear = ACNODEANGLEFTR ;
    option clear = ACBRANCHFLOWFTR ;
    option clear = DEFICITBUSGENERATIONFTR ;
    option clear = SURPLUSBUSGENERATIONFTR ;

    injectionFTR(n)  = FTRinjection(ftr,n) ;

    option bratio = 1;
    FTR_Model_sequential.Optfile = 1;
    FTR_Model_sequential.reslim = LPTimeLimit;
    FTR_Model_sequential.iterlim = LPIterationLimit;
    solve FTR_Model_sequential using lp maximizing NETBENEFIT;

    ModelSolved = 1 $ ((FTR_Model_sequential.modelstat = 1) and (FTR_Model_sequential.solvestat = 1));
*   Post a progress message to report for use by GUI and to the console.
    if( (ModelSolved <> 1),
        putclose runlog 'FRT flow calculation for injection pattern failed' /
    ) ;

    loop( i_dateTimeTradePeriodMap(dt,tp),
        FTRbranchFlow(ftr,dt,br) = Round(ACBRANCHFLOWFTR.l(tp,br), 6) ;

        FTRbrCstrLHS(ftr,dt,brCstr)
            $ (BranchConstraintSense(tp,brCstr) = -1)
            = sum[ br $ ACbranch(tp,br)
                 , BranchConstraintFactors(tp,brCstr,br)
                 * ACBRANCHFLOWFTR.l(tp,br)
                 ] ;

    ) ;
  );


else
  putclose runlog 'Vectorisation is switched ON for FTR' /;

  option clear = NETBENEFIT ;
  option clear = FTRACNODEANGLE ;
  option clear = FTRACBRANCHFLOW ;
  option clear = FTRDEFICITBUSGENERATION ;
  option clear = FTRSURPLUSBUSGENERATION ;

  option bratio = 1;
  FTR_Model.Optfile = 1;
  FTR_Model.reslim = LPTimeLimit;
  FTR_Model.iterlim = LPIterationLimit;
  solve FTR_Model using lp maximizing NETBENEFIT;

  ModelSolved = 1 $ ((FTR_Model.modelstat = 1) and (FTR_Model.solvestat = 1));
* Post a progress message to report for use by GUI and to the console.
  if( (ModelSolved <> 1),
      putclose runlog 'FRT flow calculation for injection pattern failed' /
  ) ;

  loop( i_dateTimeTradePeriodMap(dt,tp),
      FTRbranchFlow(ftr,dt,br) = Round(FTRACBRANCHFLOW.l(tp,br,ftr), 6) ;

      FTRbrCstrLHS(ftr,dt,brCstr)
          $ (BranchConstraintSense(tp,brCstr) = -1)
          = sum[ br $ ACbranch(tp,br)
               , BranchConstraintFactors(tp,brCstr,br)
               * FTRACBRANCHFLOW.l(tp,br,ftr)
               ] ;

  ) ;
) ;






*=====================================================================================
* 2. Schedule 14.6 - Calculation of loss and constraint excess to be paid into FTR account
*=====================================================================================

Parameters
  BranchPL(dt,br)                           'BranchParticipationLoading'
  BrCstrPL(dt,brCstr)                       'Branch Constraint Participation Loading'
  MxCstrPL(dt,brCstr)                       'Mixed Constraint Participation Loading'

  SchLossBlock(dt,br,los)                   'MW flow on each loss block in the direction of scheduled positive flow'
  BranchLossMargin(dt,br)                   'Loss factor margin for actual scheduled flow '
  AssBranchCap(dt,br)                       'The portion of the capacity of each AC line to be assigned'
  AssLossBlock(dt,br,los)                   'The portion of the capacity of each AC line loss curve block to be assigned'
  AssBrCstrCap(dt,brCstr)                   'A portion of the capacity of each AC line assigned for FTR rental purpose'

  ReceivingEndPrice(dt,br)                  'Nodal energy price at the receiving end of the scheduled flow on AC line'

  FTR_Branch_Rent(dt,br)                    'The amount of the loss and constraint excess generated by each AC line'
  FTR_BrCstr_Rent(dt,brCstr)                'The amount of the loss and constraint excess generated by each binding branch constraint'
  FTR_ACLoss_Rent(dt,br)                    'The amount of the loss and constraint excess generated by each AC line loss curve block'

  FTR_TradePeriodDCRent(dt)                 'Total HVDC loss and constraint excess by trading period'
  FTR_TradePeriodACRent(dt)                 'Total AC line rent by trading period'
  FTR_TradePeriodAClossRent(dt)             'Total AC loss rent by trading period'
  FTR_TradePeriodBrCstrRent(dt)             'Total branch group constraint rent by trading period'
  FTR_TradePeriodRent(dt)                   'Total FTR rent by trading period'
;

* Clause 7.2 determine branch participation loading ----------------------------
BranchPL(dt,br) $ (o_BranchFlow_TP(dt,br) >= 0)
    = SMax[ ftr, FTRbranchFlow(ftr,dt,br) ];

BranchPL(dt,br) $ (o_BranchFlow_TP(dt,br) < 0)
    = - SMin[ ftr, FTRbranchFlow(ftr,dt,br) ];


* 7.3 determine branch constraint participation loading ------------------------
BrCstrPL(dt,brCstr) $ o_brConstraintPrice_TP(dt,brCstr)
    = Smax[ ftr, FTRbrCstrLHS(ftr,dt,brCstr) ];


* Clause 7.4 determine mixed constraint participation loading ------------------
*(currently non-appplicable)


* Schedule 14.6 Clause 8.2 determine assigned branch capacity ------------------
AssBranchCap(dt,br) = Min[ BranchPL(dt,br), o_branchCapacity_TP(dt,br) ] ;


* Schedule 14.6 Clause 8.3 determine assinged AC branch loss block -------------
AssLossBlock(dt,br,los) = 0 ;
Loop(los,
    AssLossBlock(dt,br,los)
        $ { Sum[los1 $ (ord(los1) < ord(los)), AssLossBlock(dt,br,los1)]
          < AssBranchCap(dt,br) }
        = Min[ o_ACbranchLossMW(dt,br,los),
               ( AssBranchCap(dt,br)
               - Sum[ los1 $ (ord(los1)<ord(los)), AssLossBlock(dt,br,los1) ]
               )
             ];
);


* Schedule 14.6 Clause 8.4&5 determine assinged AC brach constraint capacity ---
AssBrCstrCap(dt,brCstr)
    = Max[ 0, Min[ BrCstrPL(dt,brCstr), o_brConstraintRHS_TP(dt,brCstr) ] ];


* Schedule 14.6 Clause 9.2 determine HVDC loss and constraint excess -----------
FTR_Branch_Rent(dt,br) $ o_HVDCLink(dt,br)
    = 0.5 * o_branchToBusPrice_TP(dt,br)   * o_BranchFlow_TP(dt,br)
    - 0.5 * o_branchToBusPrice_TP(dt,br)   * o_branchDynamicLoss_TP(dt,br)
    - 0.5 * o_branchFromBusPrice_TP(dt,br) * o_BranchFlow_TP(dt,br);

FTR_TradePeriodDCRent(dt)
    = Max[0, Sum[ br $ o_HVDCLink(dt,br), FTR_Branch_Rent(dt,br) ] ] ;


* Schedule 14.6 Clause 9.3 determine LC excess generated by each AC line -------
FTR_Branch_Rent(dt,br) $ (not o_HVDCLink(dt,br))
    = 0.5 * AssBranchCap(dt,br) * o_branchMarginalPrice_TP(dt,br);


* Schedule 14.6 Clause 9.4 determine LC excess generated by binding constraint -
FTR_BrCstr_Rent(dt,brCstr)
    = 0.5 * AssBrCstrCap(dt,brCstr) * o_brConstraintPrice_TP(dt,brCstr);


* Schedule 14.6 Clause 9.5 determine LC excess generated by each AC line loss --
SchLossBlock(dt,br,los) = 0 ;
Loop(los,
    SchLossBlock(dt,br,los)
        $ { Sum[los1 $ (ord(los1) < ord(los)), SchLossBlock(dt,br,los1)]
          < abs(o_BranchFlow_TP(dt,br)) }
        = Min[ o_ACbranchLossMW(dt,br,los),
               ( abs(o_BranchFlow_TP(dt,br))
               - Sum[ los1 $ (ord(los1)<ord(los)), SchLossBlock(dt,br,los1) ]
               )
             ];
);

BranchLossMargin(dt,br) $ abs(o_BranchFlow_TP(dt,br))
    = Smin[ los $ { SchLossBlock(dt,br,los) < o_ACbranchLossMW(dt,br,los) }
          , o_ACbranchLossFactor(dt,br,los) ];

ReceivingEndPrice(dt,br)
    = [ o_BranchToBusPrice_TP(dt,br)   $ (o_BranchFlow_TP(dt,br) > 0) ]
    + [ o_BranchFromBusPrice_TP(dt,br) $ (o_BranchFlow_TP(dt,br) < 0) ] ;

FTR_ACLoss_Rent(dt,br) $ (not o_HVDCLink(dt,br))
    = Sum[ los, 0.5 * ReceivingEndPrice(dt,br)
              * Min(SchLossBlock(dt,br,los), AssLossBlock(dt,br,los))
              * (BranchLossMargin(dt,br) - o_ACbranchLossFactor(dt,br,los))
         ];

* Total FTR rent by trading period ---------------------------------------------

FTR_TradePeriodACRent(dt)
    = Sum[ br $ (not o_HVDCLink(dt,br)), FTR_Branch_Rent(dt,br) ];

FTR_TradePeriodAClossRent(dt)
    = Sum[ br $ (not o_HVDCLink(dt,br)), FTR_ACLoss_Rent(dt,br) ];

FTR_TradePeriodBrCstrRent(dt)
    = Sum[ brCstr, FTR_BrCstr_Rent(dt,brCstr) ];

FTR_TradePeriodRent(dt) = FTR_TradePeriodDCRent(dt)
                        + FTR_TradePeriodACRent(dt)
                        + FTR_TradePeriodAClossRent(dt)
                        + FTR_TradePeriodBrCstrRent(dt) ;



*=====================================================================================
* 3. FTR rental report
*=====================================================================================

* FTR rental generated by HVDC
File HVDCRent             / "%OutputPath%%runName%\%runName%_HVDCRent.csv" / ;
HVDCRent.pc = 5;
HVDCRent.lw = 0;
HVDCRent.pw = 9999;
HVDCRent.ap = 1;
HVDCRent.nd = 5;
put HVDCRent;
loop((dt,br) $ [o_HVDCLink(dt,br)],
    put dt.tl, br.tl, o_branchFlow_TP(dt,br), o_branchDynamicLoss_TP(dt,br)
        o_branchFromBusPrice_TP(dt,br), o_BranchToBusPrice_TP(dt,br)
        FTR_Branch_Rent(dt,br) /;
);

* FTR rental generated by AC branch loss and constraint excess
File
ACRent               / "%OutputPath%%runName%\%runName%_ACRent.csv" / ;
ACRent.pc = 5;
ACRent.lw = 0;
ACRent.pw = 9999;
ACRent.ap = 1;
ACRent.nd = 5;
put ACRent;
loop((dt,br) $ { (not o_HVDCLink(dt,br)) and AssBranchCap(dt,br) },
    put dt.tl, br.tl, o_branchFlow_TP(dt,br);
    loop( ftr, put FTRbranchFlow(ftr,dt,br) );
    put AssBranchCap(dt,br), o_branchMarginalPrice_TP(dt,br)
        FTR_Branch_Rent(dt,br), FTR_ACLoss_Rent(dt,br) /;
);

* FTR rental generated by binding branch group constraint
File BrConstraintRent /"%OutputPath%%runName%\%runName%_BrConstraintRent.csv"/;
BrConstraintRent.pc = 5;
BrConstraintRent.lw = 0;
BrConstraintRent.pw = 9999;
BrConstraintRent.ap = 1;
BrConstraintRent.nd = 5;
put BrConstraintRent;
loop((dt,brCstr) $ AssBrCstrCap(dt,brCstr),
    put dt.tl, brCstr.tl, o_brConstraintLHS_TP(dt,brCstr)
    loop( ftr, put FTRbrCstrLHS(ftr,dt,brCstr) );
    put AssBrCstrCap(dt,brCstr), o_brConstraintPrice_TP(dt,brCstr)
        FTR_BrCstr_Rent(dt,brCstr) /;
);

* Total FTR rental
File TotalRent            / "%OutputPath%%runName%\%runName%_TotalRent.csv" /;
TotalRent.pc = 5;
TotalRent.lw = 0;
TotalRent.pw = 9999;
TotalRent.ap = 1;
TotalRent.nd = 2;
put TotalRent;
loop(dt,
  put dt.tl, FTR_TradePeriodDCRent(dt), FTR_TradePeriodACRent(dt)
      FTR_TradePeriodAClossRent(dt), FTR_TradePeriodBrCstrRent(dt)
      FTR_TradePeriodRent(dt), o_ACbranchTotalRentals(dt) /;
);


$stop
* FTR branch flow output -------------------------------------------------------
execute_unload '%outputPath%\%runName%\%vSPDinputData%_FTRoutput.gdx'
  o_dateTime, i_branch, i_branchConstraint, o_branch, o_HVDClink
  o_brConstraint_TP, o_ACbranchLossMW, o_ACbranchLossFactor
  o_branchFlow_TP, o_branchFromBusPrice_TP, o_branchToBusPrice_TP
  o_branchDynamicLoss_TP, o_branchMarginalPrice_TP, o_branchCapacity_TP
  o_brConstraintRHS_TP, o_brConstraintPrice_TP, o_ACbranchTotalRentals
  FTRpattern, FTRbranchFlow, FTRbrCstrLHS
  BranchPL = BranchParticipationLoading
  BrCstrPL = BrCstrParticipationLoading
*  MxCstrPL = Mixed Constraint Participation Loading
  SchLossBlock = ScheduledLossBlock
  BranchLossMargin
  AssBranchCap = AssignedBranchCapity
  AssLossBlock = AssignedLossBlock
  AssBrCstrCap = AssignedBranchConstraintCapity
  ReceivingEndPrice
  FTR_Branch_Rent
  FTR_BrCstr_Rent
  FTR_ACLoss_Rent

  FTR_TradePeriodDCRent
  FTR_TradePeriodACRent
  FTR_TradePeriodAClossRent
  FTR_TradePeriodBrCstrRent
  FTR_TradePeriodRent
  ;
