*=====================================================================================
* Name:                 FTRrentalCalculation.gms
* Function:             Reads data, calculate FTR rentals and write output to GDX file
*                       by day - ready to be reported on.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     30 May 2014
*=====================================================================================


$include vSPDpaths.inc
$include vSPDsettings.inc
$Include vSPDcase.inc


*Declaration =============================================================================================================================================================================
SETS
FTRdirection                              'FTR flow direction'
lossSegment /ls1*ls10/
dateTime(*)                               'Date and time for reporting'
branch(*)                                 'Branch definition for all the trading periods'
branchConstraint(*)                       'Branch constraint definition for all the trading periods'
;
Alias (lossSegment,los,los1),(dateTime,dt),(branch,br) ;
Alias (branchConstraint,brCstr), (FTRdirection,ftr) ;

SETS
dateTimeBranch(dt,br)                     'Set of FTR branches defined for the current trading period'
dateTimeHVDCLink(dt,br)                   'HVDC links (branches) defined for the current trading period'
dateTimeBranchConstraint(dt,brCstr)       'Set of FTR branches defined for the current trading period'
;


PARAMETERS
ACbranchLossMW(dt,br,los)                 'MW element of the loss segment curve in MW'
ACbranchLossFactor(dt,br,los)             'Loss factor element of the loss segment curve'
branchFlow(dt,br)                         'SPD --> MW flow on each branch for the different time periods'
branchDynamicLoss(dt,br)                  'SPD --> Branch dynamic loss (HVDC only)'
branchFromBusPrice(dt,br)                 'Branch FromBus Price'
branchToBusPrice(dt,br)                   'Branch ToBus Price'
branchMarginalPrice(dt,br)                'Branch shadow price'
branchCapacity(dt,br)                     'Branch capacity'
branchConstraintLHS(dt,brCstr)            'SPD --> Branch constraint value'
brConstraintPrice(dt,brCstr)              'SPD --> Branch constraint shadow price'

FTRbranchFlow(ftr,dt,br)                  'FRT direction --> temporary MW flow on each branch for the different time periods'
FTRbrCstrLHS(ftr,dt,brCstr)               'FRT direction --> temporary branch constraint value'


FTR_BranchLFMargin(dt,br)                 '12.e.i 9(5) Loss factor margin for actual flow '
FTR_BranchCapacity(dt,br)                 '11.a 8(2) assigned branch capacity'
FTR_BranchSegment(dt,br,los)              '11.b 8(3) assigned branch capacity amongst the loss tranches'
FTR_BranchConstraintLoading(dt,brCstr)    '11.c 8(4) assigned branch constraint participation loading'

FTR_Branch_Rent(dt,br)                    '12.a 9(2) and 12.b 9(3) --> HVDC FTR rent and AC FTR rent'
FTR_BrConstraint_Rent(dt,brCstr)          '12.c 9(4) Branch constraint rent'

FTR_ACLoss_Rent(dt,br)                    '12.e 9(5) AC Loss rent'
FTR_SegmentMarginalPrice(dt,br,los)       '12.e.i Shadow price for each infra-marginal loss tranche'

FTR_TradePeriodRent(dt)                   '13.e --> total FTR rent by trading period'
FTR_TradePeriodDCRent(dt)                 '13.e.1'
FTR_TradePeriodACRent(dt)                 '13.e.2'
FTR_TradePeriodAClossRent(dt)             '13.e.3'
FTR_TradePeriodBranchConstraintRent(dt)   '13.e.4'

ACBranchTotalRentals(dt)                  'Extra info requested by Manyu MERI'
;
*=========================================================================================================================================================================================


*Load data ===============================================================================================================================================================================

$gdxin FTRinput
$load  FTRdirection
$gdxin

$gdxin "%outputPath%%runName%\RunNum%VSPDRunNum%_FTRoutput.gdx"
$load DateTime = o_DateTime
$load Branch = i_Branch
$load BranchConstraint = i_BranchConstraint
$load DateTimeBranch = o_Branch
$load DateTimeHVDCLink = o_HVDCLink
$load DateTimeBranchConstraint = o_BrConstraint_TP
$load ACBranchLossMW = o_ACBranchLossMW
$load ACBranchLossFactor = o_ACBranchLossFactor
$load BranchFlow = o_BranchFlow_TP
$load BranchDynamicLoss = o_BranchDynamicLoss_TP
$load BranchFromBusPrice = o_BranchFromBusPrice_TP
$load BranchToBusPrice = o_BranchToBusPrice_TP
$load BranchMarginalPrice = o_BranchMarginalPrice_TP
$load BranchCapacity = o_BranchCapacity_TP
$load BranchConstraintLHS = o_BrConstraintLHS_TP
$load BrConstraintPrice = o_BrConstraintPrice_TP
$load ACBranchTotalRentals = o_ACBranchTotalRentals
$load FTRbranchFlow FTRbrCstrLHS
$gdxin


BranchFlow(dt,br) $ { (not DateTimeHVDCLink(dt,br)) and
                      (Sum[ ftr, Abs(FTRbranchFlow(ftr,dt,br)) ] < 0.00001)
                    } = 0;

BranchConstraintLHS(dt,brCstr) $ ( Sum[ftr, Abs(FTRbrCstrLHS(ftr,dt,brCstr))] < 0.00001 ) = 0 ;

BrConstraintPrice(dt,brCstr) $ ( Sum[ftr, Abs(FTRbrCstrLHS(ftr,dt,brCstr))] < 0.00001 ) = 0 ;

*=========================================================================================================================================================================================




*Process data *===========================================================================================================================================================================

* 12.e.i 9(5) Loss factor margin for actual flow ===============================
FTR_BranchSegment(dt,br,los) = 0;
Loop(los,
   FTR_BranchSegment(dt,br,los) $ { BranchFlow(dt,br) < 0 and
                                    (Sum[ los1 $ [ord(los1) < ord(los)]
                                               , FTR_BranchSegment(dt,br,los1)
                                        ] > BranchFlow(dt,br)
                                    )
                                  }
      = Max[ -ACBranchLossMW(dt,br,los),
             ( BranchFlow(dt,br)
             - Sum[ los1 $ (ord(los1) < ord(los)), FTR_BranchSegment(dt,br,los1) ]
             )
           ];

   FTR_BranchSegment(dt,br,los) $ { BranchFlow(dt,br) > 0 and
                                    (Sum[ los1 $ (ord(los1) < ord(los))
                                               , FTR_BranchSegment(dt,br,los1)
                                        ] < BranchFlow(dt,br)
                                    )
                                  }
      = Min[ ACBranchLossMW(dt,br,los),
             ( BranchFlow(dt,br)
             - Sum[ los1 $ [ord(los1) < ord(los)], FTR_BranchSegment(dt,br,los1) ]
             )
           ];

   FTR_BranchLFMargin(dt,br) $ { (Abs(FTR_BranchSegment(dt,br,los)) < ACBranchLossMW(dt,br,los)) and
                                 (Abs(FTR_BranchSegment(dt,br,los)) > 0)
                               } = ACBranchLossFactor(dt,br,los);

   FTR_BranchLFMargin(dt,br) $ { (Abs(FTR_BranchSegment(dt,br,los)) = ACBranchLossMW(dt,br,los)) and
                                 (Abs(FTR_BranchSegment(dt,br,los)) > 0)
                               } = ACBranchLossFactor(dt,br,los+1);
);


* 11.a 8(2) assigned branch capacity ===========================================
FTR_BranchCapacity(dt,br) $  (BranchFlow(dt,br) < 0)
    = Max[ BranchFlow(dt,br), SMin[ ftr, FTRbranchFlow(ftr,dt,br) ] ];

FTR_BranchCapacity(dt,br) $  (BranchFlow(dt,br) > 0)
    = Min[ BranchFlow(dt,br), SMax[ ftr, FTRbranchFlow(ftr,dt,br) ] ];


* 11.b 8(3) assigned branch capacity amongst the loss tranches =================
FTR_BranchSegment(dt,br,los) = 0;
Loop(los,
    FTR_BranchSegment(dt,br,los) $ { BranchFlow(dt,br) < 0 and
                                     (Sum[ los1 $ (ord(los1) < ord(los))
                                                , FTR_BranchSegment(dt,br,los1)
                                         ] > FTR_BranchCapacity(dt,br)
                                     )
                                   }
        = Max[ -ACBranchLossMW(dt,br,los),
               ( FTR_BranchCapacity(dt,br)
               - Sum[ los1 $ (ord(los1) < ord(los)), FTR_BranchSegment(dt,br,los1) ]
               )
             ];

    FTR_BranchSegment(dt,br,los) $ { BranchFlow(dt,br) > 0 and
                                     (Sum[ los1 $ (ord(los1) < ord(los))
                                                , FTR_BranchSegment(dt,br,los1)
                                         ] < FTR_BranchCapacity(dt,br)
                                     )
                                   }
        = Min[ ACBranchLossMW(dt,br,los),
               ( FTR_BranchCapacity(dt,br)
               - Sum[ los1 $ (ord(los1) < ord(los)), FTR_BranchSegment(dt,br,los1) ]
               )
             ];
);

FTR_BranchSegment(dt,br,los) = Abs(FTR_BranchSegment(dt,br,los));

*Roger added -------------
FTR_BranchCapacity(dt,br) = Abs(FTR_BranchCapacity(dt,br));
*-------------------------

* 11.c 8(4) assigned branch constraint participation loading ===================
FTR_BranchConstraintLoading(dt,brCstr)
    = Max[ 0, Min[ Smax[ ftr, FTRbrCstrLHS(ftr,dt,brCstr) ],
                   BranchConstraintLHS(dt,brCstr)
                 ]
         ];


* 12.a 9(2) --> HVDC FTR rent ==================================================
FTR_Branch_Rent(dt,br) $ DateTimeHVDCLink(dt,br)
    = 0.5 * BranchToBusPrice(dt,br) * [ BranchFlow(dt,br) - BranchDynamicLoss(dt,br) ]
    - 0.5 * BranchFromBusPrice(dt,br) * BranchFlow(dt,br);


* 12.b 9(3) --> AC FTR rent ====================================================
FTR_Branch_Rent(dt,br) $ (not DateTimeHVDCLink(dt,br))
    = 0.5 * FTR_BranchCapacity(dt,br) * BranchMarginalPrice(dt,br);


* 12.c 9(4) Branch constraint rent =============================================
FTR_BrConstraint_Rent(dt,brCstr) $ { FTR_BranchConstraintLoading(dt,brCstr) and
                                     BrConstraintPrice(dt,brCstr) }
    = 0.5 * FTR_BranchConstraintLoading(dt,brCstr) * BrConstraintPrice(dt,brCstr);


*===== 12.e.iii Shadow price for each infra-marginal loss tranche
FTR_SegmentMarginalPrice(dt,br,los) $ { (BranchFlow(dt,br) > 0) and
                                        (not DateTimeHVDCLink(dt,br)) and
                                        FTR_BranchSegment(dt,br,los)
                                      }
    = BranchToBusPrice(dt,br) * [ FTR_BranchLFMargin(dt,br) - ACBranchLossFactor(dt,br,los) ];


FTR_SegmentMarginalPrice(dt,br,los) $ { (BranchFlow(dt,br) < 0) and
                                        (not DateTimeHVDCLink(dt,br)) and
                                        FTR_BranchSegment(dt,br,los)
                                      }
    = BranchFromBusPrice(dt,br) * [ FTR_BranchLFMargin(dt,br) - ACBranchLossFactor(dt,br,los) ];


*===== 12.e.v AC Loss rent
FTR_ACLoss_Rent(dt,br) $ (not DateTimeHVDCLink(dt,br))
    = Sum[ los $ FTR_SegmentMarginalPrice(dt,br,los)
               , 0.5 * FTR_BranchSegment(dt,br,los) * FTR_SegmentMarginalPrice(dt,br,los)
         ];


* 13.e --> total FTR rent by trading period ====================================
FTR_TradePeriodRent(dt) = Sum[ br $ FTR_Branch_Rent(dt,br), FTR_Branch_Rent(dt,br) ]
                        + Sum[ brCstr $ FTR_BrConstraint_Rent(dt,brCstr), FTR_BrConstraint_Rent(dt,brCstr) ]
                        + Sum[ br $ FTR_ACLoss_Rent(dt,br), FTR_ACLoss_Rent(dt,br) ];


FTR_TradePeriodDCRent(dt) = Sum[ br $ { FTR_Branch_Rent(dt,br) and
                                        DateTimeHVDCLink(dt,br) }
                                    , FTR_Branch_Rent(dt,br)
                               ];

FTR_TradePeriodACRent(dt) = Sum[ br $ { FTR_Branch_Rent(dt,br) and
                                        not(DateTimeHVDCLink(dt,br)) }
                                    , FTR_Branch_Rent(dt,br)
                               ];

FTR_TradePeriodAClossRent(dt) = Sum[ br $ FTR_ACLoss_Rent(dt,br), FTR_ACLoss_Rent(dt,br) ];

FTR_TradePeriodBranchConstraintRent(dt) = Sum[ brCstr $ FTR_BrConstraint_Rent(dt,brCstr)
                                                      , FTR_BrConstraint_Rent(dt,brCstr) ];

*=========================================================================================================================================================================================

*Redefine output files - allow file to append
FILES
HVDCRent                 / "%OutputPath%%runName%\%runName%_HVDCRent.csv" /
ACRent                   / "%OutputPath%%runName%\%runName%_ACRent.csv" /
BrConstraintRent         / "%OutputPath%%runName%\%runName%_BrConstraintRent.csv" /
TotalRent                / "%OutputPath%%runName%\%runName%_TotalRent.csv" /
;

*Set output file format
HVDCRent.pc = 5;           HVDCRent.lw = 0;           HVDCRent.pw = 9999;           HVDCRent.ap = 1;
ACRent.pc = 5;             ACRent.lw = 0;             ACRent.pw = 9999;             ACRent.ap = 1;
BrConstraintRent.pc = 5;   BrConstraintRent.lw = 0;   BrConstraintRent.pw = 9999;   BrConstraintRent.ap = 1;
TotalRent.pc = 5;          TotalRent.lw = 0;          TotalRent.pw = 9999;          TotalRent.ap = 1;



put HVDCRent;
loop((dt,br) $ [DateTimeHVDCLink(dt,br)],
  put dt.tl, br.tl, BranchFlow(dt,br), BranchDynamicLoss(dt,br)
      BranchFromBusPrice(dt,br), BranchToBusPrice(dt,br),FTR_Branch_Rent(dt,br) /;
);

put ACRent;
*loop((dt,br) $ { not(DateTimeHVDCLink(dt,br)) and
*                 (FTR_Branch_Rent(dt,br) + FTR_ACLoss_Rent(dt,br) > 0.001)
*               },

*Roger suggested -------------
loop((dt,br) $ { not(DateTimeHVDCLink(dt,br)) and
                 ( (Abs(FTR_Branch_Rent(dt,br)) > 0.001) or
                   (Abs(FTR_ACLoss_Rent(dt,br)) > 0.001)
                 )
               },
*-----------------------------
  put dt.tl, br.tl, BranchFlow(dt,br);
  loop( ftr,
    put FTRbranchFlow(ftr,dt,br) ;
  );
  put FTR_BranchCapacity(dt,br), BranchMarginalPrice(dt,br)
      FTR_Branch_Rent(dt,br), FTR_ACLoss_Rent(dt,br) /;
);

put BrConstraintRent;
loop((dt,brCstr) $ FTR_BranchConstraintLoading(dt,brCstr),
  put dt.tl, brCstr.tl, BranchConstraintLHS(dt,brCstr)
  loop( ftr,
    put FTRbrCstrLHS(ftr,dt,brCstr) ;
  );
  put FTR_BranchConstraintLoading(dt,brCstr)
      BrConstraintPrice(dt,brCstr), FTR_BrConstraint_Rent(dt,brCstr) /;
);

put TotalRent;
loop(dt,
  put dt.tl, FTR_TradePeriodDCRent(dt), FTR_TradePeriodACRent(dt)
      FTR_TradePeriodAClossRent(dt), FTR_TradePeriodBranchConstraintRent(dt)
      FTR_TradePeriodRent(dt), ACBranchTotalRentals(dt) /;
);


*Uncomment the code below to export data to gdx file for testing
$ontext
* ExportData -------------------------------------------------------------------------------------------------------------------------------------------
execute_unload '%OutputPath%%runName%_Result\RunNum%VSPDRunNum%_FTR_Result.gdx'
LossSegment
FTRdirection
DateTime
Branch
BranchConstraint
DateTimeBranch
DateTimeHVDCLink
DateTimeBranchConstraint

BranchFlow
BranchDynamicLoss
FTRbranchFlow
BranchCapacity

ACBranchLossMW
ACBranchLossFactor

BranchFromBusPrice
BranchToBusPrice
BranchMarginalPrice

BranchConstraintLHS
FTRbrCstrLHS
BrConstraintPrice

FTR_BranchCapacity
FTR_BranchSegment
FTR_BranchLFMargin
FTR_BranchConstraintLoading
FTR_Branch_Rent
FTR_BrConstraint_Rent
FTR_ACLoss_Rent
FTR_SegmentMarginalPrice
FTR_TradePeriodRent
FTR_TradePeriodDCRent
FTR_TradePeriodACRent
FTR_TradePeriodAClossRent
FTR_TradePeriodBranchConstraintRent
;
*-------------------------------------------------------------------------------------------------------------------------------------------------------
$offtext


* End of file.
