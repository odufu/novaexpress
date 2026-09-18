651:   // ==========================================
652:   Widget _buildFinanceAndPosTab(bool isDark, bool isMobile) {
653:     final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
654:     final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
655: 
656:     return ListView(
657:       padding: const EdgeInsets.symmetric(vertical: 4),
658:       children: [
659:         // 1. POS Transfer Fee Strategy Card
660:         Consumer(
661:           builder: (context, ref, _) {
662:             final chargeMode = ref.watch(dcSettingsDraftProvider.select((s) => s.chargeMode));
663:             final isReimbursable = ref.watch(dcSettingsDraftProvider.select((s) => s.isReimbursable));
664: 
665:             return Container(
666:               padding: EdgeInsets.all(isMobile ? 16 : 22),
667:               decoration: BoxDecoration(
668:                 color: cardBg,
669:                 borderRadius: BorderRadius.circular(16),
670:                 border: Border.all(color: borderColor),
671:               ),
672:               child: Column(
673:                 crossAxisAlignment: CrossAxisAlignment.start,
674:                 children: [
675:                   // Header Row with Dynamic Active badge
676:                   Row(
677:                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
678:                     children: [
679:                       Expanded(
680:                         child: Column(
681:                           crossAxisAlignment: CrossAxisAlignment.start,
682:                           children: [
683:                             Text(
684:                               'POS Transfer Fee Strategy',
685:                               style: GoogleFonts.inter(
686:                                 fontSize: 15,
687:                                 fontWeight: FontWeight.bold,
688:                                 color: isDark ? Colors.white : const Color(0xFF0F172A),
689:                               ),
690:                             ),
691:                             const SizedBox(height: 2),
692:                             Text(
693:                               'Strategy for cash handover transfers and rider reimbursement thresholds.',
694:                               style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
695:                             ),
696:                           ],
697:                         ),
698:                       ),
699:                       Container(
700:                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
701:                         decoration: BoxDecoration(
702:                           color: const Color(0xFFECFDF5),
703:                           borderRadius: BorderRadius.circular(6),
704:                           border: Border.all(color: const Color(0xFFA7F3D0)),
705:                         ),
706:                         child: Row(
707:                           mainAxisSize: MainAxisSize.min,
708:                           children: [
709:                             Container(
710:                               width: 6,
711:                               height: 6,
712:                               decoration: const BoxDecoration(
713:                                 color: Color(0xFF059669),
714:                                 shape: BoxShape.circle,
715:                               ),
716:                             ),
717:                             const SizedBox(width: 6),
718:                             Text(
719:                               chargeMode == 'dynamic' ? 'DYNAMIC ACTIVE' : 'FLAT RATE ACTIVE',
720:                               style: GoogleFonts.inter(
721:                                 fontSize: 10.5,
722:                                 fontWeight: FontWeight.w800,
723:                                 color: const Color(0xFF059669),
724:                                 letterSpacing: 0.5,
725:                               ),
726:                             ),
727:                           ],
728:                         ),
729:                       ),
730:                     ],
731:                   ),
732: 
733:                   const SizedBox(height: 18),
734: 
735:                   // Strategy Choice Cards (Dynamic vs Flat Rate)
736:                   if (isMobile) ...[
737:                     _buildDynamicStrategyCard(
738:                       isSelected: chargeMode == 'dynamic',
739:                       onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('dynamic'),
740:                       isDark: isDark,
741:                     ),
742:                     const SizedBox(height: 10),
743:                     _buildFlatStrategyCard(
744:                       isSelected: chargeMode == 'flat',
745:                       onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('flat'),
746:                       isDark: isDark,
747:                     ),
748:                   ] else ...[
749:                     Row(
750:                       children: [
751:                         Expanded(
752:                           child: _buildDynamicStrategyCard(
753:                             isSelected: chargeMode == 'dynamic',
754:                             onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('dynamic'),
755:                             isDark: isDark,
756:                           ),
757:                         ),
758:                         const SizedBox(width: 14),
759:                         Expanded(
760:                           child: _buildFlatStrategyCard(
761:                             isSelected: chargeMode == 'flat',
762:                             onTap: () => ref.read(dcSettingsDraftProvider.notifier).setChargeMode('flat'),
763:                             isDark: isDark,
764:                           ),
765:                         ),
766:                       ],
767:                     ),
768:                   ],
769: 
770:                   const SizedBox(height: 20),
771: 
772:                   // Tiered Fee Parameters
773:                   if (chargeMode == 'dynamic') ...[
774:                     Text(
775:                       'TIERED FEE PARAMETERS',
776:                       style: GoogleFonts.inter(
777:                         fontSize: 11,
778:                         fontWeight: FontWeight.w800,
779:                         color: const Color(0xFF475569),
780:                         letterSpacing: 0.8,
781:                       ),
782:                     ),
783:                     const SizedBox(height: 12),
784:                     if (isMobile) ...[
785:                       _buildStyledCurrencyInput(
786:                         label: 'Tier Step Amount (₦)',
787:                         controller: _posTierAmountController,
788:                         hint: '5,000',
789:                         helper: 'Bracket increment size in Naira',
790:                         isDark: isDark,
791:                       ),
792:                       const SizedBox(height: 12),
793:                       _buildStyledCurrencyInput(
794:                         label: 'Fee per Tier (₦)',
795:                         controller: _posTierFeeController,
796:                         hint: '100',
797:                         helper: 'Cost charged per bracket increment',
798:                         isDark: isDark,
799:                       ),
800:                       const SizedBox(height: 12),
801:                       _buildStyledCurrencyInput(
802:                         label: 'Maximum Cap Fee (₦)',
803:                         controller: _posMaxCapFeeController,
804:                         hint: '1,500',
805:                         helper: 'Maximum charge ceiling per transfer',
806:                         isDark: isDark,
807:                       ),
808:                     ] else ...[
809:                       Row(
810:                         children: [
811:                           Expanded(
812:                             child: _buildStyledCurrencyInput(
813:                               label: 'Tier Step Amount (₦)',
814:                               controller: _posTierAmountController,
815:                               hint: '5,000',
816:                               helper: 'Bracket increment size in Naira',
817:                               isDark: isDark,
818:                             ),
819:                           ),
820:                           const SizedBox(width: 12),
821:                           Expanded(
822:                             child: _buildStyledCurrencyInput(
823:                               label: 'Fee per Tier (₦)',
824:                               controller: _posTierFeeController,
825:                               hint: '100',
826:                               helper: 'Cost charged per bracket increment',
827:                               isDark: isDark,
828:                             ),
829:                           ),
830:                           const SizedBox(width: 12),
831:                           Expanded(
832:                             child: _buildStyledCurrencyInput(
833:                               label: 'Maximum Cap Fee (₦)',
834:                               controller: _posMaxCapFeeController,
835:                               hint: '1,500',
836:                               helper: 'Maximum charge ceiling per transfer',
837:                               isDark: isDark,
838:                             ),
839:                           ),
840:                         ],
841:                       ),
842:                     ],
843:                   ] else ...[
844:                     _buildStyledCurrencyInput(
845:                       label: 'Fixed Flat POS Transfer Fee (₦)',
846:                       controller: _posFlatRateController,
847:                       hint: '350',
848:                       helper: 'Fixed standard flat fee per cash deposit regardless of remittance size',
849:                       isDark: isDark,
850:                     ),
851:                   ],
852: 
853:                   const SizedBox(height: 18),
854: 
855:                   // Reimbursable policy switch
856:                   Row(
857:                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
858:                     children: [
859:                       Expanded(
860:                         child: Column(
861:                           crossAxisAlignment: CrossAxisAlignment.start,
862:                           children: [
863:                             Text(
864:                               'Company Reimburses POS Transfer Fees',
865:                               style: GoogleFonts.inter(
866:                                 fontWeight: FontWeight.w700,
867:                                 fontSize: 13,
868:                                 color: isDark ? Colors.white : const Color(0xFF0F172A),
869:                               ),
870:                             ),
871:                             const SizedBox(height: 2),
872:                             Text(
873:                               'Rider retains POS charge from collected cash and it is automatically deducted into daily vault reconciliation.',
874:                               style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
875:                             ),
876:                           ],
877:                         ),
878:                       ),
879:                       Switch(
880:                         value: isReimbursable,
881:                         activeColor: const Color(0xFF4F46E5),
882:                         activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
883:                         onChanged: (val) => ref.read(dcSettingsDraftProvider.notifier).setReimbursable(val),
884:                       ),
885:                     ],
886:                   ),
887:                 ],
888:               ),
889:             );
890:           },
891:         ),
892: 
893:         const SizedBox(height: 16),
894: 
895:         // 2. LIVE FINANCIAL RECONCILIATION SIMULATOR Card (Exact UI/UX Match)
896:         Consumer(
897:           builder: (context, ref, _) {
898:             final draft = ref.watch(dcSettingsDraftProvider);
899:             final chargeMode = draft.chargeMode;
900:             final simAmount = draft.simAmount;
901:             final isReimbursable = draft.isReimbursable;
902: 
903:             final tierAmount = _parseField(_posTierAmountController, 5000.0);
904:             final feePerTier = _parseField(_posTierFeeController, 100.0);
905:             final maxCap = _parseField(_posMaxCapFeeController, 1500.0);
906:             final flatRate = _parseField(_posFlatRateController, 350.0);
907: 
908:             final tiersCount = tierAmount > 0 ? (simAmount / tierAmount).ceil() : 1;
909:             final posFee = chargeMode == 'flat'
910:                 ? flatRate
911:                 : (tiersCount * feePerTier).clamp(feePerTier, maxCap);
912: 
913:             final commission = _parseField(_commissionRateController, 1000.0);
914:             final transport = _parseField(_transportAllowanceController, 1500.0);
915:             final riderAllowance = commission + transport;
916:             final netToVault = (simAmount - riderAllowance - (isReimbursable ? posFee : 0.0)).clamp(0.0, double.infinity);
917: 
918:             return Container(
919:               padding: EdgeInsets.all(isMobile ? 16 : 22),
920:               decoration: BoxDecoration(
921:                 color: const Color(0xFF131835),
922:                 borderRadius: BorderRadius.circular(16),
923:                 border: Border.all(color: const Color(0xFF252D5E)),
924:               ),
925:               child: Column(
926:                 crossAxisAlignment: CrossAxisAlignment.start,
927:                 children: [
928:                   // Header Row
929:                   Row(
930:                     children: [
931:                       Container(
932:                         width: 36,
933:                         height: 36,
934:                         decoration: BoxDecoration(
935:                           color: const Color(0xFF1E254E),
936:                           borderRadius: BorderRadius.circular(8),
937:                         ),
938:                         child: const Center(
939:                           child: Icon(Icons.calculate_outlined, color: Color(0xFF818CF8), size: 20),
940:                         ),
941:                       ),
942:                       const SizedBox(width: 12),
943:                       Expanded(
944:                         child: Column(
945:                           crossAxisAlignment: CrossAxisAlignment.start,
946:                           children: [
947:                             Text(
948:                               'LIVE FINANCIAL RECONCILIATION SIMULATOR',
949:                               style: GoogleFonts.inter(
950:                                 fontSize: 13,
951:                                 fontWeight: FontWeight.bold,
952:                                 color: Colors.white,
953:                                 letterSpacing: 0.6,
954:                               ),
955:                             ),
956:                             const SizedBox(height: 2),
957:                             Text(
958:                               'Interactive payout formula benchmark test for rider Cash-on-Delivery handover',
959:                               style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
960:                             ),
961:                           ],
962:                         ),
963:                       ),
964:                       Container(
965:                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
966:                         decoration: BoxDecoration(
967:                           color: const Color(0xFF1C2245),
968:                           borderRadius: BorderRadius.circular(6),
969:                           border: Border.all(color: const Color(0xFF2E3868)),
970:                         ),
971:                         child: Text(
972:                           chargeMode == 'dynamic' ? 'Mode: Dynamic Tiered' : 'Mode: Flat Rate',
973:                           style: GoogleFonts.inter(
974:                             fontSize: 11,
975:                             fontWeight: FontWeight.w500,
976:                             color: const Color(0xFFCBD5E1),
977:                           ),
978:                         ),
979:                       ),
980:                     ],
981:                   ),
982: 
983:                   const SizedBox(height: 20),
984: 
985:                   // Content: Left Input + Right 4 KPI Cards
986:                   if (isMobile) ...[
987:                     _buildSimSampleInput(isDark),
988:                     const SizedBox(height: 16),
989:                     _buildSimKpiCard(
990:                       label: 'GROSS CASH',
991:                       value: '₦${_currencyFormat.format(simAmount)}',
992:                       subtitle: 'Rider Handover',
993:                       valColor: Colors.white,
994:                     ),
995:                     const SizedBox(height: 10),
996:                     _buildSimKpiCard(
997:                       label: 'POS FEE',
998:                       extraTag: chargeMode == 'dynamic' ? '($tiersCount TIERS)' : null,
999:                       badgeText: isReimbursable ? 'Reimbursed' : null,
1000:                       value: '-₦${_currencyFormat.format(posFee)}',
1001:                       subtitle: chargeMode == 'dynamic' ? '₦${feePerTier.toInt()} × $tiersCount brackets' : 'Fixed Flat Rate',
1002:                       valColor: const Color(0xFFF87171),
1003:                     ),
1004:                     const SizedBox(height: 10),
1005:                     _buildSimKpiCard(
1006:                       label: 'RIDER ALLOWANCE',
1007:                       value: '-₦${_currencyFormat.format(riderAllowance)}',
1008:                       subtitle: 'Fixed order trip payout',
1009:                       valColor: const Color(0xFFFBBF24),
1010:                     ),
1011:                     const SizedBox(height: 10),
1012:                     _buildSimKpiCard(
1013:                       label: 'NET TO VAULT',
1014:                       hasDot: true,
1015:                       value: '₦${_currencyFormat.format(netToVault)}',
1016:                       subtitle: 'Hub Cash Inflow',
1017:                       valColor: const Color(0xFF34D399),
1018:                     ),
1019:                   ] else ...[
1020:                     Row(
1021:                       crossAxisAlignment: CrossAxisAlignment.start,
1022:                       children: [
1023:                         // Left Input Field Box
1024:                         SizedBox(
1025:                           width: 250,
1026:                           child: _buildSimSampleInput(isDark),
1027:                         ),
1028:                         const SizedBox(width: 16),
1029: 
1030:                         // Right 4 KPI Cards
1031:                         Expanded(
1032:                           child: Row(
1033:                             children: [
1034:                               Expanded(
1035:                                 child: _buildSimKpiCard(
1036:                                   label: 'GROSS CASH',
1037:                                   value: '₦${_currencyFormat.format(simAmount)}',
1038:                                   subtitle: 'Rider Handover',
1039:                                   valColor: Colors.white,
1040:                                 ),
1041:                               ),
1042:                               const SizedBox(width: 10),
1043:                               Expanded(
1044:                                 child: _buildSimKpiCard(
1045:                                   label: 'POS FEE',
1046:                                   extraTag: chargeMode == 'dynamic' ? '($tiersCount TIERS)' : null,
1047:                                   badgeText: isReimbursable ? 'Reimbursed' : null,
1048:                                   value: '-₦${_currencyFormat.format(posFee)}',
1049:                                   subtitle: chargeMode == 'dynamic' ? '₦${feePerTier.toInt()} × $tiersCount brackets' : 'Fixed Flat Rate',
1050:                                   valColor: const Color(0xFFF87171),
1051:                                 ),
1052:                               ),
1053:                               const SizedBox(width: 10),
1054:                               Expanded(
1055:                                 child: _buildSimKpiCard(
1056:                                   label: 'RIDER ALLOWANCE',
1057:                                   value: '-₦${_currencyFormat.format(riderAllowance)}',
1058:                                   subtitle: 'Fixed order trip payout',
1059:                                   valColor: const Color(0xFFFBBF24),
1060:                                 ),
1061:                               ),
1062:                               const SizedBox(width: 10),
1063:                               Expanded(
1064:                                 child: _buildSimKpiCard(
1065:                                   label: 'NET TO VAULT',
1066:                                   hasDot: true,
1067:                                   value: '₦${_currencyFormat.format(netToVault)}',
1068:                                   subtitle: 'Hub Cash Inflow',
1069:                                   valColor: const Color(0xFF34D399),
1070:                                 ),
1071:                               ),
1072:                             ],
1073:                           ),
1074:                         ),
1075:                       ],
1076:                     ),
1077:                   ],
1078:                 ],
1079:               ),
1080:             );
1081:           },
1082:         ),
1083: 
1084:         const SizedBox(height: 16),
1085:       ],
1086:     );
1087:   }
1088: 
1089:   Widget _buildDynamicStrategyCard({
1090:     required bool isSelected,
1091:     required VoidCallback onTap,
1092:     required bool isDark,
1093:   }) {
1094:     return InkWell(
1095:       onTap: onTap,
1096:       borderRadius: BorderRadius.circular(12),
1097:       child: Container(
1098:         padding: const EdgeInsets.all(16),
1099:         decoration: BoxDecoration(
1100:           color: isSelected ? const Color(0xFFFFFFFF) : (isDark ? const Color(0xFF0F172A) : Colors.white),
1101:           borderRadius: BorderRadius.circular(12),
1102:           border: Border.all(
1103:             color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
1104:             width: isSelected ? 2 : 1,
1105:           ),
1106:         ),
1107:         child: Row(
1108:           children: [
1109:             Container(
1110:               width: 40,
1111:               height: 40,
1112:               decoration: BoxDecoration(
1113:                 color: const Color(0xFF4F46E5),
1114:                 borderRadius: BorderRadius.circular(8),
1115:               ),
1116:               child: const Center(
1117:                 child: Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
1118:               ),
1119:             ),
1120:             const SizedBox(width: 12),
1121:             Expanded(
1122:               child: Column(
1123:                 crossAxisAlignment: CrossAxisAlignment.start,
1124:                 children: [
1125:                   Row(
1126:                     children: [
1127:                       Text(
1128:                         'Dynamic Tiered Scaling',
1129:                         style: GoogleFonts.inter(
1130:                           fontSize: 13.5,
1131:                           fontWeight: FontWeight.w700,
1132:                           color: const Color(0xFF0F172A),
1133:                         ),
1134:                       ),
1135:                       const SizedBox(width: 8),
1136:                       Container(
1137:                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
1138:                         decoration: BoxDecoration(
1139:                           color: const Color(0xFF4F46E5),
1140:                           borderRadius: BorderRadius.circular(4),
1141:                         ),
1142:                         child: Text(
1143:                           'RECOMMENDED',
1144:                           style: GoogleFonts.inter(
1145:                             fontSize: 9,
1146:                             fontWeight: FontWeight.w800,
1147:                             color: Colors.white,
1148:                             letterSpacing: 0.5,
1149:                           ),
1150:                         ),
1151:                       ),
1152:                     ],
1153:                   ),
1154:                   const SizedBox(height: 3),
1155:                   RichText(
1156:                     text: TextSpan(
1157:                       text: 'Fee scales proportionally with transfer amount ',
1158:                       style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
1159:                       children: [
1160:                         TextSpan(
1161:                           text: '(₦100 per ₦5,000 cash)',
1162:                           style: GoogleFonts.inter(
1163:                             fontWeight: FontWeight.w700,
1164:                             color: const Color(0xFF4F46E5),
1165:                           ),
1166:                         ),
1167:                       ],
1168:                     ),
1169:                   ),
1170:                 ],
1171:               ),
1172:             ),
1173:             const SizedBox(width: 8),
1174:             Icon(
1175:               isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
1176:               color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
1177:               size: 20,
1178:             ),
1179:           ],
1180:         ),
1181:       ),
1182:     );
1183:   }
1184: 
1185:   Widget _buildFlatStrategyCard({
1186:     required bool isSelected,
1187:     required VoidCallback onTap,
1188:     required bool isDark,
1189:   }) {
1190:     return InkWell(
1191:       onTap: onTap,
1192:       borderRadius: BorderRadius.circular(12),
1193:       child: Container(
1194:         padding: const EdgeInsets.all(16),
1195:         decoration: BoxDecoration(
1196:           color: isSelected ? const Color(0xFFFFFFFF) : (isDark ? const Color(0xFF0F172A) : Colors.white),
1197:           borderRadius: BorderRadius.circular(12),
1198:           border: Border.all(
1199:             color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
1200:             width: isSelected ? 2 : 1,