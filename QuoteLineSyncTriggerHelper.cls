public class QuoteLineSyncTriggerHelper{
                                               
  public static String fmtOption(Decimal option){
        String opt = '';
        if (option != null && option != 0) {
            opt = '$' + option.toPlainString();            
        } else {
            opt = '----';
        }
        opt += '\n';
        return opt;
  }
    
  
    
  public static List<QuoteLineItem> runPBLogic(List<QuoteLineItem> qliList, List<QuoteLineItem> oqliList) {
  
      Boolean isNew;
      
      System.debug('QuoteLineSyncTriggerHelper.runPBLogic oqliList length: ' + (oqliList != null ? String.valueOf(oqliList.size()) : 'null'));
      
      Map<Id, QuoteLineItem> qliToQliMap = new Map<Id, QuoteLineItem>();
      if (oqliList != null) {
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic:Items in trigger.old');
          for (QuoteLineItem qli : oqliList) {
              if (qliToQliMap.get(qli.Id) == null) {
                  qliToQliMap.put(qli.Id, qli);         
              }
          } 
      }
      
      //  START PREVIOUS PB Logic
      System.debug('QuoteLineSyncTriggerHelper.runPBLogic:Start Calculations... ');          
 
      Product2 product2;
      PricebookEntry pricebook;      
      Id quoteId;
      
      Set<Id> productSet = new Set<Id>();
      Set<Id> pricebookSet = new Set<Id>();
      
      if (qliList != null) {
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic:Items in qliList');
          for (QuoteLineItem qli : qliList) {
              if (quoteId == null) quoteId = qli.QuoteId;
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic:qli.Product2Id'+ qli.Product2Id);
              productSet.add(qli.Product2Id);              
              pricebookSet.add(qli.PricebookEntryId);         
          } 
      }
      
      //CREATE PRICEBOOK MAP
      System.debug('QuoteLineSyncTriggerHelper.runPBLogic:Creating pricebooks');     
      Map<Id,PricebookEntry> pricebookMap=new Map<Id,PricebookEntry>([SELECT Id,UnitPrice,Product2Id FROM PricebookEntry where id in: pricebookSet]);
      System.debug('Found PricebookEntry count: ' + pricebookMap.size());
      
      for(Id id: pricebookMap.keyset()){
            PricebookEntry pricebook1 = pricebookMap.get(id);            
            if (pricebook1.Product2Id != null){
                productSet.add(pricebook1.Product2Id);
                System.debug('QuoteLineSyncTriggerHelper.runPBLogic:product2ID was added to productSet');
            } else {
                System.debug('QuoteLineSyncTriggerHelper.runPBLogic:product2ID was null');
            }           
      }
     
      
      //SET PRICE LEVEL
      String containerPriceLevel = [select id,account.Container_Accepted_Pricing_Level__c from quote where id = :quoteId limit 1].account.Container_Accepted_Pricing_Level__c;
      String compactionPriceLevel = [select id,account.Compaction_Accepted_Pricing_Level__c from quote where id = :quoteId limit 1].account.Compaction_Accepted_Pricing_Level__c;
      System.debug('Container Price Level set to:' + containerPriceLevel);
      System.debug('Compaction Price Level set to:' + compactionPriceLevel);
      
      //CREATE PRODUCT2 MAP
      Map<Id,Product2> productMap=new Map<Id,Product2>([SELECT Id,  Is_Install__C, Is_Surcharge__c, Family, Product_Group__c,Street_Discount_Price__c, National_Discount_Price__c, Republic_Price__c, Need_Price__c,
                                    Discount_1_Price__c, Discount_2_Price__c, Dealer_Discount__c, WM_Discount_Price__c, Progressive_Waste_Price__c,
                                    Waste_Pro_Price__c, Waste_Connections_Price__c, Advanced_Disposal_Price__c, Market_Price__c, Plastics_Piece__c
                      FROM Product2 where id in: productSet]);            
      System.debug('Found Product2 count: ' + productMap.size());
      
      //PROCESS EACH LINEITEM
      for(QuoteLineItem qli : qliList){
         
          //DETERMINE IF NEW OR EXISTING QLI, previous QLI values
          System.debug('Looking using qli:'+ qli.Id);
          QuoteLineItem oqli;
          if (qli.Id != null) {
            oqli = qliToQliMap.get(qli.Id);
            //System.debug('Found old qli:'+oqli.Id);
          } else {
              oqli = null;
          }       
          isNew = (qli.Id == null);          
          System.debug('isNew: ' + isNew);
          
          //SET PRICEBOOK
          System.debug('Finding pricebook using PricebookEntryId:' + qli.PricebookEntryId + ' and Product2Id:' + qli.Product2Id);
          
          if (qli.PricebookEntryId != null) { //} && qli.Product2Id != null) {
              pricebook = pricebookMap.get(qli.PricebookEntryId);
              System.debug('Found pricebook: ');
              if (pricebook != null) {
                  System.debug('Set pricebook.');               
              } else {
                  System.debug('Could not set pricebook using PricebookEntryId');                 
              }              
          } else {
              System.debug('Could not set pricebook as it is null on QLI!');
              pricebook = null;
          }
                       
          System.debug('Pricebook:' + pricebook); 
          System.debug('Pricebook.Product2Id:' + pricebook.Product2ID);
          
          //SET PRODUCT2
          System.debug('Finding product2 using: ' + qli.Product2Id);
          
          String product2Id;
          if (qli.Product2Id != null) {
              //Must be insert, get from qli
              System.debug('Getting Product2Id from qli...'); 
              product2Id = qli.Product2Id;              
              System.debug('Product2Id from qli:' + product2Id); 
          } else {
              //try getting it using pricebook 
              if (pricebook != null) {             
                  product2Id = pricebook.Product2Id;
                  System.debug('Product2Id from pricebook:' + product2Id);
              } else {
                  System.debug('Pricebook not available, cannot set set product2Id from pricebook');
              }           
          }
          
          if (product2Id != null) {
            product2 = productMap.get(product2Id);
          } else {
              System.debug('Product Id on QLI is null!');                                             
          }
          
          if (product2 == null) {
              System.debug('ERROR!  Could not find product in productMap for id:' + product2Id);
          } else {
              System.debug('Found product2 using id:' + product2Id);
          }
                    
          if (false && qli.Product2Id == null && pricebook != null && pricebook.Product2Id != null) {
              System.debug('Could not set get Product2ID, searching using pricebook');
              product2 = [SELECT Id,    Is_Install__C, Is_Surcharge__c, Family, Product_Group__c,Street_Discount_Price__c, National_Discount_Price__c, Republic_Price__c, Need_Price__c,
                                    Discount_1_Price__c, Discount_2_Price__c, Dealer_Discount__c, WM_Discount_Price__c, Progressive_Waste_Price__c,
                                    Waste_Pro_Price__c, Waste_Connections_Price__c, Advanced_Disposal_Price__c, Market_Price__c, Plastics_Piece__c
                      FROM Product2 where id = :pricebook.Product2Id];
              if (product2 == null) {
                  System.debug('Set product2 using pricebook.Product2ID:' + pricebook.Product2Id);
              } else {
                  System.debug('Could not set set product2 using pricebook.Product2ID' + pricebook.Product2Id);
              }
          } else {
              System.debug('Could not set search using pricebook.Product2ID!');
          }
          
          
          //START PB NODE LOGIC
          
          //**** Start:*******************************************************************************************
          //**** Quote Line Item Create *************************************************************             
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Quote Line Item Create -- isNew:' + isNew);    
          if (isNew && pricebook != null ) {                            
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Quote Line Item Create  -- true -- id:' + qli.Id);
              qli.Discretionary_Discount__c = 0;
              System.debug('  Updating values: qli.Discretionary_Discount__c =' + qli.Discretionary_Discount__c); 
              qli.Discretionary_Discount_Percent__c = 0;
              qli.Include_in_Discounting__c = (pricebook.UnitPrice == 0 ? 0 : 1);
              qli.Pricebook_List_Price__c = (pricebook.UnitPrice == 0 ? 0 : pricebook.UnitPrice);              
              qli.Special__c = (product2 != null && product2.Need_Price__c) ? 1 : 0;
              System.debug('  Updating values: qli.Special__c =' + qli.Special__c);                   
          } else {
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Quote Line Item Create  -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Quote Line Item Create  ');          
          //*****End:**********************************************************************************************  
          //**** Quote Line Item Create ***************************************************************************

          
          //**** Start:****************************************************************************  
          //**** Has A&D **************************************************************     
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Has A&D' );
          if (qli.Product_Group__c == '51 A&D Services' && qli.Has_A_D__c != 1) {                            
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Has A&D -- true -- id:' + qli.Id);
              qli.Has_A_D__c = 1;  
              System.debug('  Updating values: qli.Has_A_D__c          =' + qli.Has_A_D__c);              
          } else {
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Has A&D -- false ');
          }      
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Has A&D ');
          //*****End:*******************************************************************************  
          //**** Has A&D **********************************************************  
          
          
          //**** Start:****************************************************************************  
          //**** Update Republic Price **************************************************************     
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Update Republic Price -- isNew:' + isNew);          
          if (isNew) {
              if (product2 != null) {
    
                  if (product2.Republic_Price__c !=0) {
                    System.debug('QuoteLineSyncTriggerHelper.runPBLogic Update Republic Price -- true -- id:' + qli.Id);
                    qli.Republic_Price2__c = product2.Republic_Price__c;
                    System.debug('  Updating values: qli.Republic_Price2__c =' + qli.Republic_Price2__c);                   
                  } else {
                    System.debug('QuoteLineSyncTriggerHelper.runPBLogic Update Republic Price -- false -- id:' + qli.Id);
                  }
              }
          }
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Update Republic Price ');
          //*****End:**********************************************************************************************  
          //**** Update Republic Price ****************************************************************************
          
          
          //**** Start:********************************************************************************************
          //**** 2aa. Account Level Discount Compaction ***********************************************************             
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2aa. Account Level Discount Compaction -- isNew:' + isNew); 
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2aa. Account Level Discount Compaction -- pricebook:' + pricebook);  
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2aa. Account Level Discount Compaction -- product2:' + product2);   
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2aa. Account Level Discount Compaction -- unitprice:' + pricebook.UnitPrice);   
          if (isNew && pricebook != null && product2 != null && product2.Family == 'Compaction' && pricebook.UnitPrice != 0) {
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic 2aa. Account Level Discount Compaction -- true -- id:' + qli.Id);                          
              
              Double basePrice= pricebook.UnitPrice;
              switch on compactionPriceLevel {
                  when 'Street Discount Price' {
                      qli.Account_Discount__c = Math.abs(basePrice - product2.Street_Discount_Price__c);
                  }
                  when 'Discount 1 Price' {
                      qli.Account_Discount__c = Math.abs(basePrice - product2.Discount_1_Price__c);
                  }
                  when 'Discount 2 Price' {
                      qli.Account_Discount__c = Math.abs(basePrice - product2.Discount_2_Price__c);
                  }
                  when 'Dealer Price' {
                      qli.Account_Discount__c = Math.abs(basePrice - product2.Dealer_Discount__c);
                  }
                  when 'National Discount Price' {
                      qli.Account_Discount__c = Math.abs(basePrice - product2.National_Discount_Price__c);
                  }
                  when 'Republic Price' {
                      qli.Account_Discount__c = Math.abs(basePrice - product2.Republic_Price__c);
                  }
                  when else {
                      qli.Account_Discount__c = 0;
                  }
              }
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2aa. Account Level Discount Compaction --  Updating values: qli.Account_Discount__c =' + qli.Account_Discount__c);    

              qli.Account_Discount_Percent__c = pricebook.UnitPrice == 0 ? 0 : changePct(qli.Account_Discount__c / pricebook.UnitPrice);                          
              qli.Discretionary_Discount_Percent__c = changePct(qli.Discretionary_Discount__c / pricebook.UnitPrice);
              qli.Sales_Price_Override__c           = pricebook.UnitPrice - qli.Account_Discount__c - qli.Discretionary_Discount__c - qli.Volume_Discount__c; 
              System.debug('QuoteLineSyncTriggerHelper:UnitPrice before:2aa. Account Level Discount Compaction, qli.UnitPrice =' + qli.UnitPrice); 
              //qli.UnitPrice                       = pricebook.UnitPrice == qli.UnitPrice ? qli.UnitPrice - qli.Account_Discount__c : qli.UnitPrice;
              System.debug('QuoteLineSyncTriggerHelper:UnitPrice Account Discount, qli.Account_Discount_c =' + qli.Account_Discount__c);
              
              if (qli.UnitPrice == basePrice) {
                  //apply discount
                  qli.UnitPrice                         = qli.UnitPrice - qli.Account_Discount__c;
              } else {
                  qli.UnitPrice                         = qli.UnitPrice;
              }
              
              System.debug('QuoteLineSyncTriggerHelper:UnitPrice update:2aa. Account Level Discount Compaction, qli.UnitPrice =' + qli.UnitPrice);  
              qli.Volume_Discount_Percent__c        = pricebook.UnitPrice == 0 ? 0 : changePct(qli.Volume_Discount__c / pricebook.UnitPrice);
              System.debug('  Updated values:  qli.UnitPrice =' + qli.UnitPrice);               
          } else {
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic 2aa. Account Level Discount Compaction  -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: 2aa. Account Level Discount Compaction  ');          
          //*****End:******************************************************************************************* 
          //**** 2aa. Account Level Discount Compaction ********************************************************
 
          
          //**** Start:******************************************************************************************** 
          //**** 2a. Account Level Discount Container *************************************************************               
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2a. Account Level Discount Container -- isNew:' + isNew); 
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2a. Account Level Discount Container -- product2:' + product2);
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2a. Account Level Discount Container -- pricebook:' + pricebook);
          if (product2  != null) System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2a. Account Level Discount Container -- product2.Family:' + product2.Family);
          if (pricebook != null) System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2a. Account Level Discount Container -- pricebook.UnitPrice:' + pricebook.UnitPrice);
          //DW:  added IsNew to criteria, per TW, 12/8/2020
          if (product2 != null && pricebook != null && isNew && product2.Family=='Containers'               && pricebook.UnitPrice != 0 || 
             (product2 != null && pricebook != null && isNew && product2.Family=='Environmental Containers' && pricebook.UnitPrice != 0)) {
              
              		System.debug('Using pricelevel for id:' + containerPriceLevel);    
              		System.debug('QuoteLineSyncTriggerHelper.runPBLogic 2a. Account Level Discount Container -- true -- id:' + qli.Id);

              		Double basePrice= pricebook.UnitPrice;

                    switch on containerPriceLevel {
                        when 'Street Discount Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Street_Discount_Price__c);
                        }
                        when 'Discount 1 Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Discount_1_Price__c);
                        }
                        when 'Discount 2 Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Discount_2_Price__c);
                        }
                        when 'Dealer Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Dealer_Discount__c);
                        }
                        when 'National Discount Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.National_Discount_Price__c);
                        }
                        when 'Waste Management Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.WM_Discount_Price__c);
                        }      
                        when 'Progressive Waste Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Progressive_Waste_Price__c);
                        }
                        when 'Waste Pro Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Waste_Pro_Price__c);
                        } 
                        when 'Waste Connections Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Waste_Connections_Price__c);
                        } 
                        when 'Advanced Disposal Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Advanced_Disposal_Price__c);
                        } 
                        when 'Market Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Market_Price__c);
                        } 
                        when 'Republic Price' {
                            qli.Account_Discount__c = Math.abs(basePrice - product2.Republic_Price__c);
                        } 
                        when else {
                            qli.Account_Discount__c = 0;
                        }
                    }
                 
                    System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2a. Account Level Discount Container --  Updating values: qli.Account_Discount__c =' + qli.Account_Discount__c);    
                 
                    qli.Account_Discount_Percent__c = changePct(qli.Account_Discount__c / pricebook.UnitPrice);
                    qli.Discretionary_Discount_Percent__c   = changePct(qli.Discretionary_Discount__c / pricebook.UnitPrice);
                    qli.Volume_Discount__c                  = (qli.PricebookEntry.UnitPrice == 0) ? 0 : qli.Volume_Discount__c / pricebook.UnitPrice;
                    qli.Sales_Price_Override__c             = pricebook.UnitPrice - qli.Account_Discount__c - qli.Discretionary_Discount__c - qli.Volume_Discount__c;
                    System.debug('** Updating Unit Price: (' + qli.UnitPrice + ') using Account_Discount__c: ' + qli.Account_Discount__c + ', pricebook.UnitPrice:' + pricebook.UnitPrice);
                    System.debug('QuoteLineSyncTriggerHelper:UnitPrice before:2a. Account Level Discount Container, qli.UnitPrice =' + qli.UnitPrice);  
                    qli.UnitPrice                           = (pricebook.UnitPrice == qli.UnitPrice) ?  qli.UnitPrice - qli.Account_Discount__c : qli.UnitPrice;
                    System.debug('QuoteLineSyncTriggerHelper:UnitPrice update:2a. Account Level Discount Container, qli.UnitPrice =' + qli.UnitPrice);                      
                    System.debug('  Updating last value: qli.Volume_Discount__c =' + qli.Volume_Discount__c);                   
          } else {
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic 2a. Account Level Discount Container -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: 2a. Account Level Discount Container ');
          //*****End:*******************************************************************************  
          //**** 2a. Account Level Discount Container *************************************************************
        
          
          //**** Start:****************************************************************************
          //**** Update Text Values **************************************************************************** 
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Update Text Values -- isNew:' + isNew);

          if (product2 != null) {
              System.debug('Using product for id:' + qli.Product2Id);             
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Update Text Values -- true -- id:' + qli.Id);
              qli.Is_Install__c           = product2.Is_Install__c; //qli.Product2Id__r.isInsatll
              qli.Is_Surcharge__c         = product2.Is_Surcharge__c;
              qli.Product_Family_Text__c  = product2.Family;
              qli.Product_Group_Text__c   = product2.Product_Group__c;
              qli.Product_ID_Text__c      = qli.Product2Id;
              qli.Total_Price__c          = qli.TotalPrice;
              System.debug('  Updating values: qli.IsInstall__c          =' + qli.Is_Install__c);
              System.debug('  Updating values: qli.Is_Surcharge__c       =' + qli.Is_Surcharge__c);
              System.debug('  Updating values: qli.Product_Family_Text__c=' + qli.Product_Family_Text__c);
              System.debug('  Updating values: qli.Product_Group__c      =' + qli.Product_Group__c);
              System.debug('  Updating values: qli.Product_Group_Text__c =' + qli.Product_Group_Text__c);
              System.debug('  Updating values: qli.Total_Price__c        =' + qli.Total_Price__c);
          } else {   
              System.debug('Error finding product2!  Skipping.' + qli.Product2Id);
          }
          
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Update Text Values ');
          //*****End: Update Text Values***********************************************************  
          //***************************************************************************************                            
          
          
          //**** Start:******************************************************************************************** 
          //**** 1. Sales Price Change ****************************************************************************     
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 1. Sales Price Change -- isNew:' + isNew);
          //if ((!isNew && pricebook != null) && (qli.UnitPrice != oqli.UnitPrice && pricebook.UnitPrice != 0)) {          
          if ( 
                  ((!isNew && pricebook != null) && (qli.UnitPrice != oqli.UnitPrice && pricebook.UnitPrice != 0) ) ||
                  (isNew &&  pricebook != null) &&  (qli.UnitPrice != 0              && pricebook.UnitPrice != 0) )
             {              
              System.debug('Using pricebook for id:' + qli.PricebookEntryId);
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic 1. Sales Price Change -- true -- id:' + qli.Id);
              qli.Account_Discount_Percent__c       = pricebook.UnitPrice == 0 ? 0 : changePct(qli.Account_Discount__c / pricebook.UnitPrice);
              qli.Discount_Applied__c               = pricebook.UnitPrice == 0 ? 0 : (1 - (qli.UnitPrice / pricebook.UnitPrice)); 
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 1. Sales Price Change -- UnitPrice calc: (' + pricebook.UnitPrice + ') - Account_Discount__c (' + qli.Account_Discount__c + ') - Volume_Discount__c (' + qli.Volume_Discount__c + ')');  
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 1. Sales Price Change -- Discretionary_Discount__c:' + qli.Discretionary_Discount__c);  
              qli.Discretionary_Discount__c             = pricebook.UnitPrice == 0 ? 0 : pricebook.UnitPrice - qli.UnitPrice - qli.Account_Discount__c - qli.Volume_Discount__c; //qli.Account_Discount__c + qli.Volume_Discount__c;
              qli.Discretionary_Discount_Percent__c = changePct(qli.Discretionary_Discount__c / pricebook.UnitPrice);
              qli.Volume_Discount_Percent__c        = pricebook.UnitPrice == 0 ? 0 : changePct(qli.Volume_Discount__c / pricebook.UnitPrice);              
              System.debug('  Updating values: pricebook.UnitPrice:' + pricebook.UnitPrice + ', gli.Account_Discount__c:' + qli.Account_Discount__c + ', qli.Volume_Discount__c:' + qli.Volume_Discount__c);
              System.debug('  Updating values: qli.Discretionary_Discount__c =' + qli.Discretionary_Discount__c);                   
          } else {
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic 1. Sales Price Change -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: 1. Sales Price Change ');
          //*****End:**********************************************************************************************  
          //**** 1. Sales Price Change ****************************************************************************          
                     
          
          //**** Start:******************************************************************************************** 
          //**** 1c. Discretionary Discount % to # ****************************************************************       
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 1c. Discretionary Discount % to # -- isNew:' + isNew);          
          if (!isNew && pricebook != null && qli.PricebookEntryId != null 
              && qli.Discretionary_Discount_Percent__c != null && qli.Discretionary_Discount_Percent__c != oqli.Discretionary_Discount_Percent__c ) {
       
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic 1c. Discretionary Discount % to # -- true -- id:' + qli.Id);
              System.debug('Using pricebook for id:' + qli.PricebookEntryId);   
              System.debug('Using unit price of:' + qli.UnitPrice);       
              qli.Discretionary_Discount__c = (pricebook.UnitPrice * qli.Discount_Applied__c) - qli.Account_Discount__c - qli.Volume_Discount__c;
              System.debug('  Updating values: qli.Discretionary_Discount__c =' + qli.Discretionary_Discount__c + ' using Discretionary_Discount_Percent__c:' + qli.Discretionary_Discount_Percent__c);                     

          } else {
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic 1c. Discretionary Discount % to # -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: 1c. Discretionary Discount % to # ');          
          //*****End:*********************************************************************************************
          //**** 1c. Discretionary Discount % to # ***************************************************************
   
          
          //**** Start:****************************************************************************  
          //**** Pro Quantity Update **************************************************************     
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Pro Quantity Update' );              
          if (qli.Quantity != null && (oqli != null && (qli.Quantity != oqli.Quantity)) && qli.PricebookEntryId != null) {              
              if (pricebook == null) {
                  System.debug('Error finding pricebook!  Skipping.' + qli.Product2Id);               
              } else {
                  System.debug('Found pricebook for id:' + qli.PricebookEntryId);
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic Pro Quantity Update -- true -- id:' + qli.Id);
                  qli.Pricebook_Amount__c = (pricebook.UnitPrice - qli.Account_Discount__c) * qli.Quantity;             
                  System.debug('  Updating values: qli.Pricebook_Amount__c          =' + qli.Pricebook_Amount__c);
              }              
          } else {
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Pro Quantity Update -- false ');
          }      
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Pro Quantity Update ');
          //*****End:*******************************************************************************  
          //**** Pro Quantity Update **********************************************************            
          
          
          //**** Start:***************************************************************************** 
          //**** 1a.Quote Discount Change **********************************************************             
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 1a.Quote Discount Change -- isNew:' + isNew);          
          if ((pricebook != null && pricebook.UnitPrice != 0 && qli.PricebookEntryId != null)  && 
                (!isNew || 
                    ( oqli != null && 
                        (
                            (qli.Account_Discount__c != oqli.Account_Discount__c || qli.Account_Discount__c == 0) ||
                            (qli.Discretionary_Discount__c != oqli.Discretionary_Discount__c || qli.Discretionary_Discount__c == 0) ||
                            (qli.Volume_Discount__c != oqli.Volume_Discount__c || qli.Volume_Discount__c == 0)
                        )
                    )
                )
              )
              {                                                                               
                
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic 1a.Quote Discount Change -- true -- id:' + qli.Id);              
              qli.Account_Discount_Percent__c           = pricebook.UnitPrice == 0 ? 0 : changePct(qli.Account_Discount__c / pricebook.UnitPrice);
              qli.Discretionary_Discount_Percent__c     = changePct(qli.Discretionary_Discount__c / pricebook.UnitPrice);
              qli.Sales_Price_Override__c               = pricebook.UnitPrice - qli.Account_Discount__c - qli.Discretionary_Discount__c - qli.Volume_Discount__c;
              qli.Volume_Discount_Percent__c            = pricebook.UnitPrice == 0 ? 0 : (qli.Volume_Discount__c / pricebook.UnitPrice) * 100;
          } else {  
                System.debug('QuoteLineSyncTriggerHelper.runPBLogic 1a.Quote Discount Change -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: 1a.Quote Discount Change ');
          //*****End:**********************************************************************************************  
          //**** 1a.Quote Discount Change *************************************************************************
                  
          
          //**** Start:******************************************************************************************** 
          //**** 2b. Override sales price with discounts **********************************************************            
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 2b. Override sales price with discounts -- isNew:' + isNew);          
          if (!isNew && qli.Sales_Price_Override__c != null && qli.Sales_Price_Override__c != oqli.Sales_Price_Override__c ) {                            
              System.debug('Using pricebook for id:' + qli.PricebookEntryId);   
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic 2b. Override sales price with discounts -- true -- id:' + qli.Id);
              //Sales_Price field is UnitPrice
              System.debug('QuoteLineSyncTriggerHelper:UnitPrice before:2b. Override sales price with discounts, qli.UnitPrice =' + qli.UnitPrice);   
              qli.UnitPrice = qli.Sales_Price_Override__c;
              System.debug('QuoteLineSyncTriggerHelper:UnitPrice update:2b. Override sales price with discounts, qli.UnitPrice =' + qli.UnitPrice);                                 
          } else {
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic 2b. Override sales price with discounts -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: 2b. Override sales price with discounts ');          
          //*****End:*******************************************************************************  
          //**** 2b. Override sales price with discounts *************************************************************

          
          //**** Start:***************************************************************************** 
          //**** 1b. Discount Applied *************************************************************   
          if (true){          
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: 1b. Discount Applied -- isNew:' + isNew); 
              //System.debug('QuoteLineSyncTriggerHelper.runPBLogic: oqli:' + oqli.Discount_Applied__c);
              if (!isNew && qli.Discount_Applied__c != null && qli.Discount_Applied__c != oqli.Discount_Applied__c ) {
                                
                  System.debug('Using pricebook for id:' + qli.PricebookEntryId);
                  //continue;     
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic 1b. Discount Applied -- true -- id:' + qli.Id);
                  qli.Discretionary_Discount__c = (pricebook.UnitPrice * qli.Discount_Applied__c) - qli.Account_Discount__c - qli.Volume_Discount__c;
                  System.debug('  Updating values: qli.Discretionary_Discount__c =' + qli.Discretionary_Discount__c);                   
              } else {
                      System.debug('QuoteLineSyncTriggerHelper.runPBLogic 1b. Discount Applied -- false -- id:' + qli.Id);
              }                        
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: 1b. Discount Applied ');          
          	  //*****End:*********************************************************************************************
          	  //**** 1b. Discount Applied ****************************************************************************
          }
          
          //**** Start:********************************************************************************************
          //**** Fill Selected Option Toter *******************************************************             
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Fill Selected Option Toter -- Product_Type__c: ' + qli.Product_Type__c);          
          if ( (qli.Product_Type__c != null) && 
                  (qli.Product_Type__c == 'Cart (Medical Waste)' || 
                   qli.Product_Type__c == 'Cart (Pro Products)' ||
                   qli.Product_Type__c == 'Cart (Residential)' ||
                   qli.Product_Type__c == 'FEL' ||
                   qli.Product_Type__c == 'Insert' ||
                   qli.Product_Type__c == 'Lid' ||
                   qli.Product_Type__c == 'Cart (Residential) 32G')
                  )
                {
                              
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Fill Selected Option Toter -- true -- id:' + qli.Id);              
                
              String itemOptions = qli.Product_Description__c + '\n';
              if (!String.isBlank(qli.Body_Color__c))           itemOptions += ' ' + qli.Body_Color__c + '\n';
              if (!String.isBlank(qli.Lid_Color__c))            itemOptions += ' ' + qli.Lid_Color__c + '\n';
              if (!String.isBlank(qli.Body_Hot_Stamp__c))       itemOptions += ' ' + qli.Body_Hot_Stamp__c + '\n';
              if (!String.isBlank(qli.Lid_Hot_Stamp__c ))       itemOptions += ' ' + qli.Lid_Hot_Stamp__c + '\n';
              if (!String.isBlank(qli.Lid_IML_Position__c))     itemOptions += ' ' + qli.Lid_IML_Position__c + '\n';
              if (!String.isBlank(qli.Wheel_Option__c ))        itemOptions += ' ' + qli.Wheel_Option__c + '\n';
              if (!String.isBlank(qli.Stopbar__c ))             itemOptions += ' ' + qli.Stopbar__c + '\n';
              if (!String.isBlank(qli.Axle__c ))                itemOptions += ' ' + qli.Axle__c + '\n';
              if (!String.isBlank(qli.Palnut__c ))              itemOptions += ' ' + qli.Palnut__c + '\n';
              if (!String.isBlank(qli.Lid_Insert__c ))          itemOptions += ' ' + qli.Lid_Insert__c + '\n';
              if (!String.isBlank(qli.Serial_Number__c ))       itemOptions += ' ' + qli.Serial_Number__c + '\n';
              if (!String.isBlank(qli.RFID__c ))                itemOptions += ' ' + qli.RFID__c + '\n';
              if (!String.isBlank(qli.Lid_Option__c ))          itemOptions += ' ' + qli.Lid_Option__c + '\n';
              if (!String.isBlank(qli.Assembly__c ))            itemOptions += ' ' + qli.Assembly__c + '\n';
              if (!String.isBlank(qli.Warranty__c ))            itemOptions += ' ' + qli.Warranty__c + '\n';
              qli.Itemized_Options__c = itemOptions;
              System.debug('  Updating values: qli.Itemized_Options__c =' + qli.Itemized_Options__c);
                
              qli.Modified_Cart_ASP__c = qli.Base_Cart__c + qli.Body_Color_ASP__c + qli.Lid_Color_ASP__c + 
                  qli.Body_Hot_Stamp_ASP__c + qli.Lid_Hot_Stamp_ASP__c + qli.Lid_IML_ASP__c + 
                  qli.Wheels_ASP__c + qli.Stopbar_ASP__c + qli.Axle_ASP__c + 
                  qli.Palnut_ASP__c + qli.Lid_Insert_ASP__c + qli.RFID_ASP__c + 
                  qli.Lid_Option_ASP__c + qli.Assembly_ASP__c + qli.Warranty_ASP__c + 
                  qli.Serial_Number_ASP__c;                                    
              System.debug('  Updating values: qli.Modified_Cart_ASP__c =' + qli.Modified_Cart_ASP__c);                                    
                   
              string optionCharges = '$' + qli.Modified_Cart_Price__c + '\n';                      
                                    
              if (!String.isBlank(qli.Body_Color__c))           optionCharges += fmtOption(qli.Body_Color_Charge__c);                      
              if (!String.isBlank(qli.Lid_Color__c))            optionCharges += fmtOption(qli.Lid_Color_Charge__c );
              if (!String.isBlank(qli.Body_Hot_Stamp__c))       optionCharges += fmtOption(qli.Body_Hot_Stamp_Charge__c );
              if (!String.isBlank(qli.Lid_Hot_Stamp__c))        optionCharges += fmtOption(qli.Lid_Hot_Stamp_Charge__c );
              if (!String.isBlank(qli.Lid_IML_Position__c))     optionCharges += fmtOption(qli.Lid_IML_Charge__c );
              if (!String.isBlank(qli.Wheel_Option__c))         optionCharges += fmtOption(qli.Wheels_Charge__c );
              if (!String.isBlank(qli.Stopbar__c ))             optionCharges += fmtOption(qli.Stopbar_Charge__c );
              if (!String.isBlank(qli.Axle__c ))                optionCharges += fmtOption(qli.Axle_Charge__c );
              if (!String.isBlank(qli.Palnut__c ))              optionCharges += fmtOption(qli.Palnut_Charge__c );
              if (!String.isBlank(qli.Lid_Insert__c  ))         optionCharges += fmtOption(qli.Lid_Insert_Charge__c );
              if (!String.isBlank(qli.Serial_Number__c ))       optionCharges += fmtOption(qli.Serial_Number_Charge__c );
              if (!String.isBlank(qli.RFID__c  ))               optionCharges += fmtOption(qli.RFID_Charge__c );
              if (!String.isBlank(qli.Lid_Option__c ))          optionCharges += fmtOption(qli.Lid_Option_Charge__c );
              if (!String.isBlank(qli.Assembly__c ))            optionCharges += fmtOption(qli.Assembly_Charge__c );
              if (!String.isBlank(qli.Warranty__c ))            optionCharges += fmtOption(qli.Warranty_Charge__c );
              
              qli.Option_Charges__c = optionCharges;
              System.debug('  Updating values: qli.Option_Charges__c =' + qli.Option_Charges__c);
                                    
              string selOption = '';
              if (!String.isBlank(qli.Body_Color__c))       selOption += qli.Body_Color__c + '\n';
              if (!String.isBlank(qli.Lid_Color__c))        selOption += qli.Lid_Color__c  + '\n';
              if (!String.isBlank(qli.Body_Hot_Stamp__c))   selOption += qli.Body_Hot_Stamp__c  + ' in ' + (qli.Body_Hot_Stamp_Color__c != null ? qli.Body_Hot_Stamp_Color__c : '(Not provided)') +'\n';
              if (!String.isBlank(qli.Lid_Hot_Stamp__c))    selOption += qli.Lid_Hot_Stamp__c   + ' in ' + (qli.Lid_Hot_Stamp_Color__c  != null ? qli.Lid_Hot_Stamp_Color__c  : '(Not provided)') +'\n';
              
              string iml = qli.Lid_IML_Size__c != null ? qli.Lid_IML_Size__c : ''; 
              if (iml.length() >= 36) iml = iml.substring(22,35);
              if (!String.isBlank(qli.Lid_IML_Position__c)) selOption += qli.Lid_IML_Position__c    + ' ' + (iml != null ? iml : '') + '\n'; 
                                    
              if (!String.isBlank(qli.Wheel_Option__c))     selOption += qli.Wheel_Option__c  + '\n';
              if (!String.isBlank(qli.Stopbar__c))          selOption += qli.Stopbar__c  + '\n';
              if (!String.isBlank(qli.Axle__c))             selOption += qli.Axle__c  + '\n';
              if (!String.isBlank(qli.Palnut__c ))          selOption += qli.Palnut__c  + '\n';
              if (!String.isBlank(qli.Lid_Insert__c ))      selOption += qli.Lid_Insert__c  + '\n';
              if (!String.isBlank(qli.Serial_Number__c))    selOption += qli.Serial_Number__c  + '\n';
              if (!String.isBlank(qli.RFID__c ))            selOption += qli.RFID__c  + '\n';
              if (!String.isBlank(qli.Lid_Option__c))       selOption += qli.Lid_Option__c  + '\n';
              if (!String.isBlank(qli.Assembly__c))         selOption += qli.Assembly__c  + '\n';
              if (!String.isBlank(qli.Warranty__c))         selOption += qli.Warranty__c  + '\n';
              
              qli.Selected_Option__c = selOption;                                    
              System.debug('  Updating values: qli.Selected_Option__c =' + qli.Selected_Option__c); 
                
          } else {
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic Fill Selected Option Toter -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Fill Selected Option Toter ');          
          //*****End:**********************************************************************************************
          //**** Fill Selected Option Toter *******************************************************
            
          
          //**** Start:********************************************************************************************
          //**** Fill Selected Options Container/compaction *******************************************************             
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Fill Selected Options Container/compaction -- isNew:' + isNew);          
          if ( (isNew && (qli.Compactor_Color__c            != null || 
                          qli.Compactor_Feed_Side__c        != null || 
                          qli.Compactor_Quick_Disconnect__c != null || 
                          qli.Compactor_Voltage__c          != null || 
                          qli.Hopper_Color__c               != null))
                ||
              (!isNew && oqli != null && 
                        //(qli.Compactor_Color__c != null && qli.Compactor_Feed_Side__c != null && qli.Hopper_Color__c != null &&
                        //  && qli.Compactor_Quick_Disconnect__c != null && qli.Compactor_Voltage__c != null)
                        //  &&
                        (qli.Compactor_Color__c != oqli.Compactor_Color__c || 
                         qli.Compactor_Feed_Side__c != oqli.Compactor_Feed_Side__c || 
                         qli.Hopper_Color__c != oqli.Hopper_Color__c || 
                         qli.Compactor_Quick_Disconnect__c != oqli.Compactor_Quick_Disconnect__c || 
                         qli.Compactor_Voltage__c != oqli.Compactor_Voltage__c)
               )
              )
              {
                              
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Fill Selected Options Container/compaction -- true -- id:' + qli.Id);
                  /*System.debug('  Updating values: Compactor_Color__c =' + qli.Compactor_Color__c);
                  System.debug('  Updating values: Compactor_Voltage__c =' + qli.Compactor_Voltage__c);
                  System.debug('  Updating values: Hopper_Color__c =' + qli.Hopper_Color__c);
                  System.debug('  Updating values: Compactor_Feed_Side__c =' + qli.Compactor_Feed_Side__c);
                  System.debug('  Updating values: Compactor_Quick_Disconnect__c =' + qli.Compactor_Quick_Disconnect__c);*/
              String selOption = '';                           
                  selOption += (String.isNotEmpty(qli.Compactor_Color__c)               ? 'Color: ' + qli.Compactor_Color__c + '\n' : '');
                  selOption += (String.isNotEmpty(qli.Compactor_Voltage__c)         ? 'Voltage: ' + qli.Compactor_Voltage__c + '\n' : '');   
                  selOption += (String.isNotEmpty(qli.Hopper_Color__c)              ? 'Hopper Color: ' + qli.Hopper_Color__c + '\n' : '');   
                  selOption += (String.isNotEmpty(qli.Compactor_Feed_Side__c)       ? 'Feed Side: ' + qli.Compactor_Feed_Side__c + '\n' : ''); 
                  selOption += (String.isNotEmpty(qli.Compactor_Quick_Disconnect__c)    ? 'Quick Disconnect: ' + qli.Compactor_Quick_Disconnect__c : '');
              qli.Selected_Option__c = selOption;
              System.debug('  Updating values: selOption =' + selOption);
              System.debug('  Updating values: qli.Selected_Option__c =' + qli.Selected_Option__c);                     
          } else {
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic Fill Selected Options Container/compaction -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Fill Selected Options Container/compaction ');          
          //*****End:**********************************************************************************************
          //**** Fill Selected Options Container/compaction *******************************************************

          
          //**** Start:********************************************************************************************
          //**** Quote Line item qty change ***********************************************************************   
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Quote Line item qty change -- isNew:' + isNew);          
          if ( (isNew && qli.Quantity > 0) 
              || (!isNew && qli.Quantity > 0 && qli.Quantity != oqli.Quantity) ) {
                                          
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Quote Line item qty change -- true -- id:' + qli.Id);
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Quote Line item qty change qli.Quantity:' + qli.Quantity);
              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Quote Line item qty change qli.Pricebook_List_Price__c:' + qli.Pricebook_List_Price__c);
              System.debug('  Updating values: qli.List_Subtotal__c =' + qli.List_Subtotal__c);                     
          } else { 
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic Quote Line item qty change  -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Quote Line item qty change  ');          
          //*****End:**********************************************************************************************  
          //**** Quote Line item qty change ***********************************************************************

          
          //**** Start:*****************************************************************************************
          //**** Update # of Carts **************************************************************            
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Update # of Carts -- isNew:' + isNew);  
          if ( (isNew && product2 != null && product2.Plastics_Piece__c == 'Cart' && qli.Quantity != null && qli.Quantity != 0) 
                ||
               (!isNew && qli.Quantity != oqli.Quantity && qli.Quantity != 0 && qli.Quantity > 0) && product2.Plastics_Piece__c == 'Cart') 
              {

              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Update # of Carts -- true -- id:' + qli.Id);  
              qli.of_Carts__c = qli.Quantity;
              System.debug('  Updating values: qli.of_Carts__c =' + qli.of_Carts__c);                   
          } else {
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic Update # of Carts -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Update # of Carts ');          
          //*****End:******************************************************************************************* 
          //**** Update # of Carts **************************************************************
          
 
          //**** Start:*****************************************************************************************
          //**** Populate Production ID on Create **************************************************************            
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: Start: Populate Production ID on Create -- isNew:' + isNew);          
          if (isNew && qli.id != null && qli.Production_ID__c != '' ) {

              System.debug('QuoteLineSyncTriggerHelper.runPBLogic Populate Production ID on Create -- true -- id:' + qli.Id);
              String idStr = qli.Id;
              id myId = idStr;
              idStr = myId;
              qli.Production_ID__c = idStr;
              System.debug('  Updating values: qli.Production_ID__c =' + qli.Production_ID__c);                     
          } else {
                  System.debug('QuoteLineSyncTriggerHelper.runPBLogic Populate Production ID on Create -- false -- id:' + qli.Id);
          }                        
          System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End: Populate Production ID on Create ');          
          //*****End:******************************************************************************************* 
          //**** Populate Production ID on Create **************************************************************

          //END ALL FORMULAS!
          
          System.debug('  Updating values: qli.UnitPrice                         =' + qli.UnitPrice);
          System.debug('  Updating values: qli.TotalPrice                        =' + qli.TotalPrice);
          System.debug('  Updating values: qli.Account_Discount__c               =' + qli.Account_Discount__c);
          System.debug('  Updating values: qli.Account_Discount_Percent__c       =' + qli.Account_Discount_Percent__c);
          System.debug('  Updating values: qli.Discretionary_Discount__c         =' + qli.Discretionary_Discount__c);
          System.debug('  Updating values: qli.Discretionary_Discount_Percent__c =' + qli.Discretionary_Discount_Percent__c);
          System.debug('  Updating values: qli.Product_Family__c                 =' + qli.Product_Family__c);
          System.debug('  Updating values: qli.Product_Family_Text__c            =' + qli.Product_Family_Text__c);
      
      }
      
      System.debug('QuoteLineSyncTriggerHelper.runPBLogic: End');
      return qliList;
      
  }
 
  public static void updateTrigger(List<QuoteLineItem> quoteLineItems, Map<Id,QuoteLineItem> oldMap, boolean triggerIsInsert, boolean triggerIsUpdate ) {
 
    /*
     if (trigger.isBefore && trigger.isInsert) { 
        if (QuoteSyncUtil.isRunningTest) {
            for (QuoteLineItem qli : trigger.new) {
                QuoteSyncUtil.populateRequiredFields(qli);
            }
        }    
        return;
    } 
    */
    if (TriggerStopper.stopQuoteLine) return;
        
    Set<String> quoteLineFields = QuoteSyncUtil.getQuoteLineFields();
    List<String> oppLineFields = QuoteSyncUtil.getOppLineFields();
    
    String qliFields = QuoteSyncUtil.getQuoteLineFieldsString();
    
    String oliFields = QuoteSyncUtil.getOppLineFieldsString();
            
    String qliIds = '';
    for (QuoteLineItem qli : quoteLineItems) {
    //        /* change by DW on 10/28/2020 to detect PB and exit */
    //          if (qli.Quote_Line_Item_Trigger_Stopper__c == true) {
    //           continue;
    //        }
    //        /* end 10/28/20 change */
        if (qliIds != '') qliIds += ', ';
            qliIds += '\'' + qli.Id + '\'';
        }
     
    /* change by DW on 10/28/2020 to detect PB and exit */
    if (qliIds == '') {
       return;
    }
    /* end 10/28/20 change */
    
    String qliQuery = 'select Id, QuoteId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + qliFields + ' from QuoteLineItem where Id in (' + qliIds + ') order by QuoteId, SortOrder ASC';
    //System.debug(qliQuery); 
        
    List<QuoteLineItem> qlis = Database.query(qliQuery);
    
    Map<Id, List<QuoteLineItem>> quoteToQliMap = new Map<Id, List<QuoteLineItem>>();
    
    for (QuoteLineItem qli : qlis) {    
        List<QuoteLineItem> qliList = quoteToQliMap.get(qli.QuoteId);
        if (qliList == null) {
            qliList = new List<QuoteLineItem>();
        } 
        qliList.add(qli);  
        quoteToQliMap.put(qli.QuoteId, qliList);        
    }

    Set<Id> quoteIds = quoteToQliMap.keySet();
    Map<Id, Quote> quotes = new Map<Id, Quote>([select id, OpportunityId, isSyncing from Quote where Id in :quoteIds]);
    
    String oppIds = '';
    Set<Id> filterQuoteIds = new Set<Id>();
    for (Quote quote : quotes.values()) {
        // Only sync quote line item that are inserted for a new Quote or on a isSyncing Quote
        if ((trigger.isInsert && QuoteSyncUtil.isNewQuote(quote.Id)) || quote.isSyncing) {
           if (oppIds != '') oppIds += ', ';
           oppIds += '\'' + quote.OpportunityId + '\'';         
        } else {
            filterQuoteIds.add(quote.Id);
        }
    } 
      
    
    //System.debug('Filter quote ids: ' + filterQuoteIds);
    
    quoteIds.removeAll(filterQuoteIds);
    for (Id id : filterQuoteIds) {
       quotes.remove(id);
       quoteToQliMap.remove(id);
    }   
   
    if (oppIds != '') {   
        String oliQuery = 'select Id, OpportunityId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + oliFields + ' from OpportunityLineItem where OpportunityId in (' + oppIds + ') order by OpportunityId, SortOrder ASC';   
        //System.debug(qliQuery);    
        
        List<OpportunityLineItem> olis = Database.query(oliQuery);    
        
        Map<Id, List<OpportunityLineItem>> oppToOliMap = new Map<Id, List<OpportunityLineItem>>();
        
        for (OpportunityLineItem oli : olis) {
            List<OpportunityLineItem> oliList = oppToOliMap.get(oli.OpportunityId);
            if (oliList == null) {
                oliList = new List<OpportunityLineItem>();
            } 
            oliList.add(oli);  
            oppToOliMap.put(oli.OpportunityId, oliList);       
        } 
     
        Set<OpportunityLineItem> updateOlis = new Set<OpportunityLineItem>();
        Set<QuoteLineItem> updateQlis = new Set<QuoteLineItem>();
              
        for (Quote quote : quotes.values()) {
                
            List<OpportunityLineItem> opplines = oppToOliMap.get(quote.OpportunityId);
            
            // for quote line insert, there will not be corresponding opp line
            if (opplines == null) continue;        

            Set<OpportunityLineItem> matchedOlis = new Set<OpportunityLineItem>();
        
            for (QuoteLineItem qli : quoteToQliMap.get(quote.Id)) {
            
                boolean updateOli = false;
                QuoteLineItem oldQli = null;
                
                if (trigger.isUpdate) {
                    oldQli = oldMap.get(qli.Id);
                    //System.debug('Old qli: ' + oldQli.UnitPrice + ', ' + oldQli.Quantity + ', ' + oldQli.Discount + ', ' + oldQli.ServiceDate);
                    //System.debug('New qli: ' + qli.UnitPrice + ', ' + qli.Quantity + ', ' + qli.Discount + ', ' + qli.ServiceDate);
                    
                    if (qli.UnitPrice == oldQli.UnitPrice
                        && qli.Quantity == oldQli.Quantity
                        && qli.Discount == oldQli.Discount
                        && qli.ServiceDate == oldQli.ServiceDate
                        && qli.SortOrder == oldQli.SortOrder 
                       )
                        updateOli = true;                       
                }
                
                                                                      
                boolean hasChange = false;
                boolean match = false;
                  
                for (OpportunityLineItem oli : opplines) {          
                    if (oli.pricebookentryid == qli.pricebookentryId  
                        && oli.UnitPrice == qli.UnitPrice
                        && oli.Quantity == qli.Quantity
                        && oli.Discount == qli.Discount
                        && oli.ServiceDate == qli.ServiceDate
                        && oli.SortOrder == qli.SortOrder
                       ) {
                        
                        if (updateOlis.contains(oli) || matchedOlis.contains(oli)) continue;  
                        
                        matchedOlis.add(oli);                       
                                               
                        for (String qliField : quoteLineFields) {
                            String oliField = QuoteSyncUtil.getQuoteLineFieldMapTo(qliField);
                            Object oliValue = oli.get(oliField);
                            Object qliValue = qli.get(qliField);
                            if (oliValue != qliValue) { 
                                                                                                
                                if (trigger.isInsert && (qliValue == null || (qliValue instanceof Boolean && !Boolean.valueOf(qliValue)))) {
                                
                                    //System.debug('Insert trigger, isSyncing: ' + quote.isSyncing + ', new quote ids: ' + QuoteSyncUtil.getNewQuoteIds());
                                    
                                    // If it's a newly created Quote, don't sync the "Description" field value, 
                                    // because it's already copied from Opportunity Line Item on create. 
                                    if (quote.isSyncing || (QuoteSyncUtil.isNewQuote(quote.Id) && !qliField.equalsIgnoreCase('description'))) {                                     
                                        qli.put(qliField, oliValue);
                                        hasChange = true; 
                                    }    
                                   
                                } else if (trigger.isUpdate && !updateOli /*&& oldQli != null*/) {
                                    //Object oldQliValue = oldQli.get(qliField);
                                    //if (qliValue == oldQliValue) {
                                        if (oliValue == null) qli.put(qliField, null);
                                        else qli.put(qliField, oliValue);
                                        hasChange = true;
                                    //}     
                                     
                                } else if (trigger.isUpdate && updateOli) {
                                    if (qliValue == null) oli.put(oliField, null);
                                    else oli.put(oliField, qliValue);
                                    hasChange = true;  
                                }
                            }    
                        }
                        
                        if (hasChange) {
                            if (trigger.isInsert || (trigger.isUpdate && !updateOli)) { 
                                updateQlis.add(qli);
                            } else if (trigger.isUpdate && updateOli) {                               
                                updateOlis.add(oli);
                            }                    
                        } 
                        
                        match = true;      
                        break;                          
                    } 
                }
                
                // NOTE: this cause error when there is workflow field update that fired during record create
                //if (trigger.isUpdate && updateOli) System.assert(match, 'No matching oppline');     
            }
        }
     
        TriggerStopper.stopOpp = true;
        TriggerStopper.stopQuote = true;             
        TriggerStopper.stopOppLine = true;
        TriggerStopper.stopQuoteLine = true;    
                    
        if (!updateOlis.isEmpty()) { 
            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
            oliList.addAll(updateOlis);
                            
            Database.update(olilist);  
            //String jsonSerializeList = JSON.serialize(olilist);    
            //System.debug('jsonSerializeList ===== ' + jsonSerializeList);
            //QuoteSyncFutureHandler.updateQuoteLines(jsonSerializeList);            
        }
        
        if (!updateQlis.isEmpty()) {
            List<QuoteLineItem> qliList = new List<QuoteLineItem>();   
            qliList.addAll(updateQlis);
                              
            Database.update(qliList);
            //String jsonSerializeList = JSON.serialize(qliList);    
            //System.debug('jsonSerializeList ===== ' + jsonSerializeList);
            //QuoteSyncFutureHandler.updateQuoteLines(jsonSerializeList);               
        }
        
        if (Trigger.isInsert) {
           QuoteSyncUtil.removeAllNewQuoteIds(quoteIds);
        }   
    }
  }
    
  public static Decimal changePct(Decimal num) {
        Decimal rounded = 0;
        
        if (num != null) {
            num = num * 100;
            //rounded = num.setScale(2, RoundingMode.HALF_UP);
            rounded = num;//num.setScale(2, RoundingMode.HALF_UP);
            //if (num.doubleValue() > 100) {
            //    rounded = 100;
            //}
            System.debug('QuoteLineSyncTriggerHelper.changePct:' + rounded.doubleValue());
            return rounded; 
        }
        return rounded;  
    }
    
}