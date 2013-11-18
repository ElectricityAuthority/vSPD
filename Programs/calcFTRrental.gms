*=====================================================================================
* Name:                 calcFTRrental.gms
* Function:             Reads data, calculate FTR rentals and write output to GDX file
*                       by day - ready to be reported on.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Last modified on:     18 November 2013
*=====================================================================================


$include vSPDpaths.inc
$include vSPDsettings.inc
$include vSPDcase.inc


*=====================================================================================
* Declare required symbols.
*=====================================================================================
Sets
  lossSegment /ls1*ls10/
  dateTime(*)                                                    'Date and time for reporting'
  branch(*)                                                      'Branch definition for all the trading periods'
  branchConstraint(*)                                            'Branch constraint definition for all the trading periods'

  DateTimeBranch(DateTime,Branch)                                'Set of FTR branches defined for the current trading period'
  DateTimeHVDCLink(DateTime,Branch)                              'HVDC links (branches) defined for the current trading period'
  DateTimeBranchConstraint(DateTime,BranchConstraint)            'Set of FTR branches defined for the current trading period'
  ;

Alias (lossSegment,lossSeg,lossSeg1) ;

Parameters
  ACbranchLossMW(DateTime,Branch,LossSegment)                    'MW element of the loss segment curve in MW'
  ACbranchLossFactor(DateTime,Branch,LossSegment)                'Loss factor element of the loss segment curve'
  branchFlow(DateTime,Branch)                                    'SPD --> MW flow on each branch for the different time periods'
  branchDynamicLoss(DateTime,Branch)                             'SPD --> Branch dynamic loss (HVDC only)'
  branchFlow_1(DateTime,Branch)                                  'FRT pattern 1 --> MW flow on each branch for the different time periods'
  branchFlow_2(DateTime,Branch)                                  'FRT pattern 2 --> MW flow on each branch for the different time periods'
  branchFromBusPrice(DateTime,Branch)                            'Branch FromBus Price'
  branchToBusPrice(DateTime,Branch)                              'Branch ToBus Price'
  branchMarginalPrice(DateTime,Branch)                           'Branch shadow price'
  branchCapacity(DateTime,Branch)                                'Branch capacity'
  branchConstraintLHS(DateTime,BranchConstraint)                 'SPD --> Branch constraint value'
  branchConstraintLHS_1(DateTime,BranchConstraint)               'FRT pattern 1 --> Branch constraint value'
  branchConstraintLHS_2(DateTime,BranchConstraint)               'FRT pattern 2 --> Branch constraint value'
  brConstraintPrice(DateTime,BranchConstraint)                   'SPD --> Branch constraint shadow price'

  FTR_branchLFMargin(DateTime,Branch)                            '12.e.i 9(5) Loss factor margin for actual flow '
  FTR_branchCapacity(DateTime,Branch)                            '11.a 8(2) assigned branch capacity'
  FTR_branchSegment(DateTime,Branch,LossSegment)                 '11.b 8(3) assigned branch capacity amongst the loss tranches'
  FTR_branchConstraintLoading(DateTime,BranchConstraint)         '11.c 8(4) assigned branch constraint participation loading'

  FTR_branch_Rent(DateTime,Branch)                               '12.a 9(2) and 12.b 9(3) --> HVDC FTR rent and AC FTR rent'
  FTR_brConstraint_Rent(DateTime,BranchConstraint)               '12.c 9(4) Branch constraint rent'

  FTR_ACloss_Rent(DateTime,Branch)                               '12.e 9(5) AC Loss rent'
  FTR_segmentMarginalPrice(DateTime,Branch,LossSegment)          '12.e.i Shadow price for each infra-marginal loss tranche'

  FTR_tradePeriodRent(DateTime)                                  '13.e --> total FTR rent by trading period'
  FTR_tradePeriodDCRent(DateTime)                                '13.e.1'
  FTR_tradePeriodACRent(DateTime)                                '13.e.2'
  FTR_tradePeriodAClossRent(DateTime)                            '13.e.3'
  FTR_tradePeriodBranchConstraintRent(DateTime)                  '13.e.4'

  ACbranchTotalRentals(DateTime)                                 'Extra info requested by Manyu MERI'
  ;


*=====================================================================================
* Load data.
*=====================================================================================
$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_BranchOutput_TP.gdx"
$load dateTime = o_DateTime
$load branch = i_Branch
$load branchConstraint = i_BranchConstraint
$load dateTimeBranch = o_Branch
$load dateTimeHVDCLink = o_HVDCLink
$load dateTimeBranchConstraint = o_BrConstraint_TP
$load ACbranchLossMW = o_ACBranchLossMW
$load ACbranchLossFactor = o_ACBranchLossFactor
$load branchFlow = o_BranchFlow_TP
$load branchDynamicLoss = o_BranchDynamicLoss_TP
$load branchFromBusPrice = o_BranchFromBusPrice_TP
$load branchToBusPrice = o_BranchToBusPrice_TP
$load branchMarginalPrice = o_BranchMarginalPrice_TP
$load branchCapacity = o_BranchCapacity_TP
$load branchConstraintLHS = o_BrConstraintLHS_TP
$load brConstraintPrice = o_BrConstraintPrice_TP
$load ACbranchTotalRentals = o_ACBranchTotalRentals
$gdxin

$gdxin "%OutputPath%%runName%_1\RunNum%VSPDRunNum%_BranchOutput_TP.gdx"
$load BranchFlow_1 = o_BranchFlow_TP
$load BranchConstraintLHS_1 = o_BrConstraintLHS_TP
$gdxin

$gdxin "%OutputPath%%runName%_2\RunNum%VSPDRunNum%_BranchOutput_TP.gdx"
$load branchFlow_2 = o_BranchFlow_TP
$load branchConstraintLHS_2 = o_BrConstraintLHS_TP
$gdxin

BranchFlow(DateTime,Branch) $ [(not DateTimeHVDCLink(DateTime,Branch)) and (Abs(BranchFlow_1(DateTime,Branch)) + Abs(BranchFlow_2(DateTime,Branch)) < 0.00001)] = 0;
BranchConstraintLHS(DateTime,BranchConstraint) $ [Abs(BranchConstraintLHS_1(DateTime,BranchConstraint)) + Abs(BranchConstraintLHS_2(DateTime,BranchConstraint)) < 0.00001] = 0;
BrConstraintPrice(DateTime,BranchConstraint) $ [BranchConstraintLHS_1(DateTime,BranchConstraint) + BranchConstraintLHS_2(DateTime,BranchConstraint)  = 0] = 0;


*=====================================================================================
* Process data.
*=====================================================================================

* 12.e.i 9(5) Loss factor margin for actual flow
FTR_BranchSegment(DateTime,Branch,LossSegment) = 0;
Loop(LossSegment,
   FTR_BranchSegment(DateTime,Branch,LossSegment) $
                                                  [ BranchFlow(DateTime,Branch) < 0 and
                                                    (Sum[LossSeg $ [ord(LossSeg) < ord(LossSegment)], FTR_BranchSegment(DateTime,Branch,LossSeg)] > BranchFlow(DateTime,Branch))
                                                  ] = Max[-ACBranchLossMW(DateTime,Branch,LossSegment), BranchFlow(DateTime,Branch) - Sum[LossSeg $ [ord(LossSeg) < ord(LossSegment)], FTR_BranchSegment(DateTime,Branch,LossSeg)]];

   FTR_BranchSegment(DateTime,Branch,LossSegment) $
                                                  [ BranchFlow(DateTime,Branch) > 0 and
                                                    (Sum[LossSeg $ [ord(LossSeg) < ord(LossSegment)], FTR_BranchSegment(DateTime,Branch,LossSeg)] < BranchFlow(DateTime,Branch))
                                                  ] = Min[ACBranchLossMW(DateTime,Branch,LossSegment), BranchFlow(DateTime,Branch) - Sum[LossSeg $ [ord(LossSeg) < ord(LossSegment)], FTR_BranchSegment(DateTime,Branch,LossSeg)]];

   FTR_BranchLFMargin(DateTime,Branch) $ [ Abs(FTR_BranchSegment(DateTime,Branch,LossSegment)) < ACBranchLossMW(DateTime,Branch,LossSegment) and
                                           Abs(FTR_BranchSegment(DateTime,Branch,LossSegment)) > 0] = ACBranchLossFactor(DateTime,Branch,LossSegment) ;

   FTR_BranchLFMargin(DateTime,Branch) $ [ Abs(FTR_BranchSegment(DateTime,Branch,LossSegment)) = ACBranchLossMW(DateTime,Branch,LossSegment) and
                                           Abs(FTR_BranchSegment(DateTime,Branch,LossSegment)) > 0] = ACBranchLossFactor(DateTime,Branch,LossSegment+1) ;
) ;


* 11.a 8(2) assigned branch capacity
FTR_BranchCapacity(DateTime,Branch) $  [BranchFlow(DateTime,Branch) < 0] = Max[BranchFlow(DateTime,Branch),Min[BranchFlow_1(DateTime,Branch),BranchFlow_2(DateTime,Branch)]];
FTR_BranchCapacity(DateTime,Branch) $  [BranchFlow(DateTime,Branch) > 0] = Min[BranchFlow(DateTime,Branch),Max[BranchFlow_1(DateTime,Branch),BranchFlow_2(DateTime,Branch)]];


* 11.b 8(3) assigned branch capacity amongst the loss tranches
FTR_BranchSegment(DateTime,Branch,LossSegment) = 0;
Loop(LossSegment,
   FTR_BranchSegment(DateTime,Branch,LossSegment) $
                                                  [ BranchFlow(DateTime,Branch) < 0 and
                                                    (Sum[LossSeg $ [ord(LossSeg) < ord(LossSegment)], FTR_BranchSegment(DateTime,Branch,LossSeg)] > FTR_BranchCapacity(DateTime,Branch))
                                                  ] = Max[-ACBranchLossMW(DateTime,Branch,LossSegment), FTR_BranchCapacity(DateTime,Branch) - Sum[LossSeg $ [ord(LossSeg) < ord(LossSegment)], FTR_BranchSegment(DateTime,Branch,LossSeg)]];

   FTR_BranchSegment(DateTime,Branch,LossSegment) $
                                                  [ BranchFlow(DateTime,Branch) > 0 and
                                                    (Sum[LossSeg $ [ord(LossSeg) < ord(LossSegment)], FTR_BranchSegment(DateTime,Branch,LossSeg)] < FTR_BranchCapacity(DateTime,Branch))
                                                  ] = Min[ACBranchLossMW(DateTime,Branch,LossSegment), FTR_BranchCapacity(DateTime,Branch) - Sum[LossSeg $ [ord(LossSeg) < ord(LossSegment)], FTR_BranchSegment(DateTime,Branch,LossSeg)]];
) ;
FTR_BranchSegment(DateTime,Branch,LossSegment) = Abs(FTR_BranchSegment(DateTime,Branch,LossSegment)) ;

FTR_BranchCapacity(DateTime,Branch) = Abs(FTR_BranchCapacity(DateTime,Branch)) ;


* 11.c 8(4) assigned branch constraint participation loading
FTR_BranchConstraintLoading(DateTime,BranchConstraint) = Min[ Max[ BranchConstraintLHS_1(DateTime,BranchConstraint), BranchConstraintLHS_2(DateTime,BranchConstraint)], BranchConstraintLHS(DateTime,BranchConstraint)];
FTR_BranchConstraintLoading(DateTime,BranchConstraint) = Max[ 0, FTR_BranchConstraintLoading(DateTime,BranchConstraint)];


* 12.a 9(2) --> HVDC FTR rent
FTR_Branch_Rent(DateTime,Branch) $ DateTimeHVDCLink(DateTime,Branch) =
   0.5 * BranchToBusPrice(DateTime,Branch) * [BranchFlow(DateTime,Branch) - BranchDynamicLoss(DateTime,Branch)]
 - 0.5 * BranchFromBusPrice(DateTime,Branch) * BranchFlow(DateTime,Branch) ;


* 12.b 9(3) --> AC FTR rent
FTR_Branch_Rent(DateTime,Branch) $ (not DateTimeHVDCLink(DateTime,Branch)) = 0.5 * FTR_BranchCapacity(DateTime,Branch) * BranchMarginalPrice(DateTime,Branch) ;


* 12.c 9(4) Branch constraint rent
FTR_BrConstraint_Rent(DateTime,BranchConstraint) $ [FTR_BranchConstraintLoading(DateTime,BranchConstraint) and BrConstraintPrice(DateTime,BranchConstraint)]
   = 0.5 * FTR_BranchConstraintLoading(DateTime,BranchConstraint) * BrConstraintPrice(DateTime,BranchConstraint) ;


* 12.c 9(4) Loss rent

* 12.e.iii Shadow price for each infra-marginal loss tranche
FTR_SegmentMarginalPrice(DateTime,Branch,LossSegment) $ [(BranchFlow(DateTime,Branch) > 0) and
                                                         (not DateTimeHVDCLink(DateTime,Branch)) and
                                                         FTR_BranchSegment(DateTime,Branch,LossSegment)] =
   BranchToBusPrice(DateTime,Branch) * [FTR_BranchLFMargin(DateTime,Branch) - ACBranchLossFactor(DateTime,Branch,LossSegment)];

FTR_SegmentMarginalPrice(DateTime,Branch,LossSegment) $ [(BranchFlow(DateTime,Branch) < 0) and
                                                         (not DateTimeHVDCLink(DateTime,Branch)) and
                                                         FTR_BranchSegment(DateTime,Branch,LossSegment)] =
   BranchFromBusPrice(DateTime,Branch) * [FTR_BranchLFMargin(DateTime,Branch) - ACBranchLossFactor(DateTime,Branch,LossSegment)];

* 12.e.v AC Loss rent
FTR_ACLoss_Rent(DateTime,Branch) $ (not DateTimeHVDCLink(DateTime,Branch)) =
   Sum[LossSegment $ FTR_SegmentMarginalPrice(DateTime,Branch,LossSegment), 0.5 * FTR_BranchSegment(DateTime,Branch,LossSegment) * FTR_SegmentMarginalPrice(DateTime,Branch,LossSegment)];


* 13.e --> total FTR rent by trading period
FTR_TradePeriodRent(DateTime) = Sum[Branch $ FTR_Branch_Rent(DateTime,Branch), FTR_Branch_Rent(DateTime,Branch)]
                              + Sum[BranchConstraint $ FTR_BrConstraint_Rent(DateTime,BranchConstraint), FTR_BrConstraint_Rent(DateTime,BranchConstraint)]
                              + Sum[Branch $ FTR_ACLoss_Rent(DateTime,Branch), FTR_ACLoss_Rent(DateTime,Branch)];


FTR_TradePeriodDCRent(DateTime) = Sum[Branch $ [FTR_Branch_Rent(DateTime,Branch) and DateTimeHVDCLink(DateTime,Branch)], FTR_Branch_Rent(DateTime,Branch)];
FTR_TradePeriodACRent(DateTime) = Sum[Branch $ [FTR_Branch_Rent(DateTime,Branch) and not(DateTimeHVDCLink(DateTime,Branch))], FTR_Branch_Rent(DateTime,Branch)];
FTR_TradePeriodAClossRent(DateTime) = Sum[Branch $ FTR_ACLoss_Rent(DateTime,Branch), FTR_ACLoss_Rent(DateTime,Branch)];
FTR_TradePeriodBranchConstraintRent(DateTime) =  Sum[BranchConstraint $ FTR_BrConstraint_Rent(DateTime,BranchConstraint), FTR_BrConstraint_Rent(DateTime,BranchConstraint)];


*=====================================================================================
* Declare output files and allow them to be appended.
*=====================================================================================

Files
  HVDCRent                 / "%OutputPath%%runName%_Result\%runName%_HVDCRent.csv" /
  ACRent                   / "%OutputPath%%runName%_Result\%runName%_ACRent.csv" /
  BrConstraintRent         / "%OutputPath%%runName%_Result\%runName%_BrConstraintRent.csv" /
  TotalRent                / "%OutputPath%%runName%_Result\%runName%_TotalRent.csv" /
  ;

* Set output file format
HVDCRent.pc = 5;               HVDCRent.lw = 0;                 HVDCRent.pw = 9999;                 HVDCRent.ap = 1;
ACRent.pc = 5;                 ACRent.lw = 0;                   ACRent.pw = 9999;                   ACRent.ap = 1;
BrConstraintRent.pc = 5;       BrConstraintRent.lw = 0;         BrConstraintRent.pw = 9999;         BrConstraintRent.ap = 1;
TotalRent.pc = 5;              TotalRent.lw = 0;                TotalRent.pw = 9999;                TotalRent.ap = 1;

put HVDCRent;
loop((DateTime,Branch) $ [DateTimeHVDCLink(DateTime,Branch)],
  put DateTime.tl, Branch.tl, BranchFlow(DateTime,Branch), BranchDynamicLoss(DateTime,Branch)
      BranchFromBusPrice(DateTime,Branch), BranchToBusPrice(DateTime,Branch),FTR_Branch_Rent(DateTime,Branch) /;
) ;

put ACRent;
loop((DateTime,Branch) $ [not(DateTimeHVDCLink(DateTime,Branch)) and ([Abs(FTR_Branch_Rent(DateTime,Branch)) > 0.001] or [Abs(FTR_ACLoss_Rent(DateTime,Branch)) > 0.001]) ],
  put DateTime.tl, Branch.tl, BranchFlow(DateTime,Branch), BranchFlow_1(DateTime,Branch), BranchFlow_2(DateTime,Branch)
      FTR_BranchCapacity(DateTime,Branch), BranchMarginalPrice(DateTime,Branch), FTR_Branch_Rent(DateTime,Branch), FTR_ACLoss_Rent(DateTime,Branch) /;
) ;

put BrConstraintRent;
loop((DateTime,BranchConstraint) $ FTR_BranchConstraintLoading(DateTime,BranchConstraint),
  put DateTime.tl, BranchConstraint.tl
      BranchConstraintLHS(DateTime,BranchConstraint), BranchConstraintLHS_1(DateTime,BranchConstraint), BranchConstraintLHS_2(DateTime,BranchConstraint)
      FTR_BranchConstraintLoading(DateTime,BranchConstraint), BrConstraintPrice(DateTime,BranchConstraint), FTR_BrConstraint_Rent(DateTime,BranchConstraint) /;
) ;

put TotalRent;
loop(DateTime,
  put DateTime.tl, FTR_TradePeriodDCRent(DateTime), FTR_TradePeriodACRent(DateTime)
      FTR_TradePeriodAClossRent(DateTime), FTR_TradePeriodBranchConstraintRent(DateTime), FTR_TradePeriodRent(DateTime), ACBranchTotalRentals(DateTime) /;
) ;



* Uncomment the code below to export data to GDX file when testing
$ontext
execute_unload '%OutputPath%%runName%_Result\RunNum%VSPDRunNum%_FTR_Result.gdx'
  lossSegment
  dateTime
  branch
  branchConstraint
  dateTimeBranch
  dateTimeHVDCLink
  dateTimeBranchConstraint

  branchFlow
  branchDynamicLoss
* branchFixedLoss
  branchFlow_1
  branchFlow_2
  branchCapacity

  ACbranchLossMW
  ACbranchLossFactor

  branchFromBusPrice
  branchToBusPrice
  branchMarginalPrice

  branchConstraintLHS
  branchConstraintLHS_1
  branchConstraintLHS_2
  brConstraintPrice

  FTR_branchCapacity
  FTR_branchSegment
  FTR_branchLFMargin
  FTR_branchConstraintLoading
  FTR_branch_Rent
  FTR_brConstraint_Rent
  FTR_ACloss_Rent
  FTR_segmentMarginalPrice
  FTR_tradePeriodRent
  FTR_tradePeriodDCRent
  FTR_tradePeriodACRent
  FTR_tradePeriodAClossRent
  FTR_tradePeriodBranchConstraintRent
  ;
$offtext
