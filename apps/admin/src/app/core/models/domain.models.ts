/** Types du domaine Kadjane, alignés sur `docs/api-contract.md`.
 *
 *  Les valeurs d'énumération sont celles renvoyées par FastAPI : aucune
 *  traduction n'a lieu sur le fil, seulement à l'affichage.
 */

export type OrgRole =
  | 'super_admin'
  | 'admin'
  | 'president'
  | 'treasurer'
  | 'auditor'
  | 'member';

export type MemberStatus = 'active' | 'inactive' | 'suspended' | 'pending';
export type Gender = 'male' | 'female' | 'unspecified';
export type OrganizationStatus = 'active' | 'suspended' | 'archived';

export type TontineStatus =
  | 'draft'
  | 'pending'
  | 'active'
  | 'suspended'
  | 'completed'
  | 'cancelled';

export type TontineFrequency = 'weekly' | 'biweekly' | 'monthly' | 'custom';
export type AllocationMode = 'monthly_draw' | 'full_order_draw' | 'manual_order';

export type CycleStatus =
  | 'upcoming'
  | 'collecting'
  | 'ready_for_draw'
  | 'drawn'
  | 'paid_out'
  | 'closed';

export type ContributionStatus =
  | 'pending'
  | 'partial'
  | 'paid'
  | 'late'
  | 'cancelled';

export type PaymentStatus = 'pending' | 'confirmed' | 'rejected' | 'cancelled';

export type PaymentMethod =
  | 'cash'
  | 'wave'
  | 'orange_money'
  | 'mtn_momo'
  | 'moov_money'
  | 'bank_transfer'
  | 'other';

export type DrawStatus = 'scheduled' | 'completed' | 'cancelled' | 'invalidated';
export type BeneficiaryStatus =
  | 'designated'
  | 'payout_pending'
  | 'paid'
  | 'cancelled';
export type PayoutStatus = 'pending' | 'processing' | 'paid' | 'failed';
export type TransactionType = 'income' | 'expense';
export type ReminderLevel = 'upcoming' | 'due_today' | 'late' | 'escalated';

export interface User {
  id: string;
  firstName: string;
  lastName: string;
  phone: string;
  email: string | null;
  avatarUrl: string | null;
  gender: Gender;
  birthDate: string | null;
  createdAt: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
}

export interface AuthSession {
  user: User;
  tokens: AuthTokens;
}

export interface OrganizationSettings {
  requireFullPaymentBeforeDraw: boolean;
  allowDrawOverride: boolean;
  latePaymentGraceDays: number;
  notifyBeforeDueDays: number;
}

export interface Organization {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  logoUrl: string | null;
  currency: string;
  country: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  rules: string | null;
  settings: OrganizationSettings;
  status: OrganizationStatus;
  createdBy: string | null;
  createdAt: string;
}

export interface Member {
  id: string;
  organizationId: string;
  user: User;
  role: OrgRole;
  status: MemberStatus;
  joinedAt: string;
  memberNumber: string | null;
  /** Présent uniquement dans la réponse de création, quand le backend a
   *  généré le mot de passe. Il n'est lisible qu'à cet instant. */
  temporaryPassword?: string;
}

export interface MemberPayload {
  firstName: string;
  lastName: string;
  phone: string;
  email?: string | null;
  role: OrgRole;
  status?: MemberStatus;
  /** Mot de passe provisoire choisi par l'administrateur. Omis, le backend en
   *  génère un et le renvoie dans `Member.temporaryPassword`. */
  password?: string | null;
}

export interface Tontine {
  id: string;
  organizationId: string;
  name: string;
  description: string | null;
  contributionAmount: number;
  currency: string;
  frequency: TontineFrequency;
  allocationMode: AllocationMode;
  startDate: string;
  dueDayOfPeriod: number;
  customPeriodDays: number | null;
  status: TontineStatus;
  requireAllContributionsBeforeDraw: boolean;
  allowDrawOverride: boolean;
  createdBy: string;
  createdAt: string;
  activatedAt: string | null;
  closedAt: string | null;
}

export interface TontineCycle {
  id: string;
  tontineId: string;
  index: number;
  periodLabel: string;
  periodStart: string;
  periodEnd: string;
  dueDate: string;
  expectedAmount: number;
  collectedAmount: number;
  remainingAmount: number;
  status: CycleStatus;
  beneficiaryParticipantId: string | null;
  beneficiaryId: string | null;
  drawSessionId: string | null;
  payoutId: string | null;
}

export interface TontineSummary {
  tontine: Tontine;
  participantCount: number;
  completedCycles: number;
  totalCycles: number;
  collectedCurrentCycle: number;
  expectedCurrentCycle: number;
  currentCycle: TontineCycle | null;
  currentBeneficiaryName: string | null;
  previousBeneficiaryName: string | null;
}

export interface TontineParticipant {
  id: string;
  tontineId: string;
  memberId: string;
  displayName: string;
  avatarUrl: string | null;
  joinedAt: string;
  isActive: boolean;
  isEligibleForDraw: boolean;
  hasReceivedPot: boolean;
  receivedCycleId: string | null;
  orderPosition: number | null;
}

export interface TontinePayload {
  name: string;
  description?: string | null;
  contributionAmount: number;
  currency: string;
  frequency: TontineFrequency;
  allocationMode: AllocationMode;
  startDate: string;
  dueDayOfPeriod: number;
  memberIds: string[];
  manualOrder?: string[];
  requireAllContributionsBeforeDraw: boolean;
  allowDrawOverride: boolean;
}

/** Un paiement replacé dans le contexte de sa cotisation. */
export interface ContributionPayment {
  id: string;
  organizationId: string;
  tontineId: string;
  cycleId: string;
  contributionId: string;
  memberId: string;
  memberName: string;
  amount: number;
  status: PaymentStatus;
  method: PaymentMethod;
  reference: string | null;
  comment: string | null;
  attachmentId: string | null;
  paidAt: string | null;
  recordedBy: string | null;
  recordedAt: string;
  cancelledAt: string | null;
  cancelReason: string | null;
}

/** Ce qu'un participant doit pour un cycle. */
export interface ContributionLine {
  id: string;
  organizationId: string;
  tontineId: string;
  cycleId: string;
  participantId: string;
  memberId: string;
  memberName: string;
  avatarUrl: string | null;
  expectedAmount: number;
  paidAmount: number;
  remainingAmount: number;
  status: ContributionStatus;
  dueDate: string;
  hasReceivedPot: boolean;
  payments: ContributionPayment[];
}

export interface ContributionTotals {
  expected: number;
  collected: number;
  remaining: number;
  paid_count: number;
  late_count: number;
  total: number;
}

export interface PaymentPayload {
  cycleId?: string;
  memberId?: string;
  contributionId?: string;
  amount: number;
  method: PaymentMethod;
  status?: PaymentStatus;
  reference?: string | null;
  comment?: string | null;
  proofUrl?: string | null;
  paidAt?: string | null;
}

export interface DrawParticipant {
  participantId: string;
  memberId: string;
  displayName: string;
  weight: number;
}

export interface DrawSession {
  id: string;
  organizationId: string;
  tontineId: string;
  cycleId: string;
  periodLabel: string;
  drawType: string;
  participants: DrawParticipant[];
  status: DrawStatus;
  executedAt: string | null;
  createdAt: string;
  winnerParticipantId: string | null;
  winnerMemberId: string | null;
  winnerName: string | null;
  launchedByMemberId: string | null;
  proofReference: string;
  randomSourceLabel: string;
  overrideUsed: boolean;
  overrideReason: string | null;
  closedAt: string | null;
  closeReason: string | null;
}

export interface DrawEligibility {
  allowed: boolean;
  reason: string;
  missingContributions: number;
  canOverride: boolean;
  can_draw: boolean;
  participants_count: number;
  eligible_count: number;
  eligible_participants: DrawParticipant[];
  remaining_contributions: number;
  remaining_amount: number;
  override_allowed: boolean;
}

export interface Beneficiary {
  id: string;
  organizationId: string;
  tontineId: string;
  cycleId: string;
  participantId: string;
  memberId: string;
  memberName: string;
  avatarUrl: string | null;
  amount: number;
  designatedAt: string;
  source: string;
  status: BeneficiaryStatus;
  drawSessionId: string | null;
  payoutId: string | null;
}

export interface Payout {
  id: string;
  organizationId: string;
  tontineId: string;
  cycleId: string;
  beneficiaryId: string;
  memberId: string;
  memberName: string;
  amount: number;
  status: PayoutStatus;
  method: PaymentMethod;
  reference: string | null;
  comment: string | null;
  sentAt: string | null;
  confirmedAt: string | null;
  failureReason: string | null;
  createdAt: string;
}

export interface PayoutPayload {
  beneficiaryId: string;
  amount: number;
  method: PaymentMethod;
  status?: PayoutStatus;
  reference?: string | null;
  comment?: string | null;
  proofUrl?: string | null;
  sentAt?: string | null;
}

export interface CashTransaction {
  id: string;
  organizationId: string;
  type: TransactionType;
  category: string;
  amount: number;
  date: string;
  createdAt: string;
  description: string | null;
  attachmentId: string | null;
  tontineId: string | null;
  createdBy: string | null;
  source: 'payment' | 'payout' | 'manual';
}

export interface TreasurySnapshot {
  balance: number;
  inflows: number;
  outflows: number;
  /** Cotisations de tontine encaissées — elles ressortent en versements. */
  contributionsTotal: number;
  /** Cotisations de caisse encaissées — celles-ci restent dans l'association. */
  duesTotal: number;
  transactions: CashTransaction[];
}

export type DuesPlanStatus = 'active' | 'paused' | 'closed';

/** Cotisation périodique due à l'association, hors tontine. */
export interface DuesPlan {
  id: string;
  organizationId: string;
  name: string;
  description: string | null;
  amount: number;
  currency: string;
  frequency: TontineFrequency;
  dueDay: number;
  startDate: string;
  status: DuesPlanStatus;
  createdAt: string;
  summary?: DuesPlanSummary;
}

export interface DuesPlanSummary {
  expectedTotal: number;
  collectedTotal: number;
  outstandingTotal: number;
  unpaidCount: number;
  memberCount: number;
  currentPeriod: number;
}

/** Ce qu'un membre doit pour une période donnée. */
export interface DuesEntry {
  id: string;
  organizationId: string;
  planId: string;
  memberId: string;
  member?: Member;
  sequenceNumber: number;
  periodLabel: string;
  periodStart: string;
  periodEnd: string;
  dueDate: string;
  expectedAmount: number;
  paidAmount: number;
  remainingAmount: number;
  status: ContributionStatus;
}

export interface DuesPlanPayload {
  name: string;
  amount: number;
  description?: string | null;
  frequency?: TontineFrequency;
  dueDay?: number;
  startDate?: string | null;
}

export interface DuesPaymentPayload {
  amount: number;
  paymentMethod: PaymentMethod;
  reference?: string | null;
  comment?: string | null;
}

export interface ReportLine {
  tontineId: string;
  tontineName: string;
  status: TontineStatus;
  expected: number;
  collected: number;
  distributed: number;
  participants: number;
}

export interface ReportSnapshot {
  totalExpected: number;
  totalCollected: number;
  totalDistributed: number;
  membersCount: number;
  activeTontines: number;
  lines: ReportLine[];
}

export interface AuditLog {
  id: string;
  organizationId: string;
  action: string;
  description: string;
  actorMemberId: string | null;
  actorName: string;
  targetType: string | null;
  targetId: string | null;
  tontineId: string | null;
  amount: number | null;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface AppNotification {
  id: string;
  userId: string;
  organizationId: string | null;
  type: string;
  title: string;
  body: string;
  targetRoute: string | null;
  data: Record<string, string>;
  readAt: string | null;
  createdAt: string;
}

export interface ReminderTarget {
  memberId: string;
  memberName: string;
  tontineId: string;
  tontineName: string;
  cycleId: string;
  periodLabel: string;
  dueDate: string;
  amountDue: number;
  level: ReminderLevel;
  daysLate: number;
  hasReceivedPot: boolean;
}

export interface UpcomingDeadline {
  tontineId: string;
  tontineName: string;
  cycleId: string;
  periodStart: string;
  dueDate: string;
  amount: number;
  isPaid: boolean;
}

export interface TrendPoint {
  periodStart: string;
  collected: number;
  expected: number;
}

export interface NextDraw {
  tontineId: string;
  tontineName: string;
  cycleId: string;
  periodStart: string;
  scheduledAt: string;
  eligibleCount: number;
  potAmount: number;
  isUnlocked: boolean;
}

export interface CurrentBeneficiary {
  tontineId: string;
  tontineName: string;
  cycleId: string;
  memberName: string;
  avatarUrl: string | null;
  amount: number;
  periodStart: string | null;
  isPaidOut: boolean;
}

export interface Dashboard {
  organization: Organization;
  membersCount: number;
  activeTontines: number;
  expectedThisPeriod: number;
  collectedThisPeriod: number;
  lateContributions: number;
  myContributionDue: number;
  myContributionPaid: number;
  deadlines: UpcomingDeadline[];
  recentActivity: AuditLog[];
  trend: TrendPoint[];
  nextDraw: NextDraw | null;
  currentBeneficiary: CurrentBeneficiary | null;
  remaining_this_month: number;
  collection_rate: number;
}

export interface RoleDefinition {
  id: string;
  organizationId: string;
  role: OrgRole;
  permissions: string[];
  isCustomized: boolean;
}

export interface Attachment {
  id: string;
  url: string;
  fileName: string;
  mimeType: string;
  sizeBytes: number;
}

// --- Phase 7 : RBAC, caisses, campagnes de cotisation ------------------------

/** Une entrée de `/me/permissions` : le rôle **dépend** de l'organisation. */
export interface MyPermissions {
  organizationId: string;
  memberId: string;
  role: OrgRole | string;
  roleId: string | null;
  roleName: string;
  permissions: string[];
}

export interface Permission {
  id: string;
  code: string;
  name: string;
  description: string;
  category: string;
}

export type RoleStatus = 'active' | 'disabled';

export interface Role {
  id: string;
  organizationId: string;
  /** Code du rôle. `role` est conservé pour les gardes historiques. */
  code: string;
  role: string;
  name: string;
  description: string;
  isSystem: boolean;
  /** Vrai quand l'organisation a pris la main sur le gabarit partagé. */
  isCustomized: boolean;
  status: RoleStatus;
  permissions: string[];
  permissionCount: number;
  memberCount: number;
  updatedAt: string | null;
}

export interface RolePayload {
  name: string;
  description?: string;
  code?: string | null;
  permissions: string[];
}

export type CashboxStatus = 'open' | 'closed' | 'suspended';

export interface Cashbox {
  id: string;
  organizationId: string;
  name: string;
  description: string | null;
  currency: string;
  openingBalance: number;
  /** Calculé par le backend : il n'existe pas de colonne de solde. */
  currentBalance: number;
  inflows: number;
  outflows: number;
  status: CashboxStatus;
  isDefault: boolean;
  createdBy: string | null;
  createdAt: string;
  updatedAt: string;
  closedAt: string | null;
}

export interface CashboxPayload {
  name: string;
  description?: string | null;
  currency?: string;
  openingBalance?: number;
  isDefault?: boolean;
}

export type CashTransactionStatus = 'confirmed' | 'cancelled' | 'reversed';

export type CashMovementType = 'income' | 'expense' | 'transfer' | 'adjustment';

export interface CashboxTransaction {
  id: string;
  organizationId: string;
  cashboxId: string | null;
  type: CashMovementType;
  category: string;
  status: CashTransactionStatus;
  amount: number;
  date: string;
  createdAt: string;
  description: string | null;
  reference: string | null;
  attachmentId: string | null;
  tontineId: string | null;
  createdBy: string | null;
  cancelledAt: string | null;
  cancelReason: string | null;
  source: string;
}

export interface CashTransactionPayload {
  type: CashMovementType;
  category: string;
  amount: number;
  date?: string | null;
  description?: string | null;
  reference?: string | null;
}

export type ContributionType =
  | 'tontine'
  | 'association'
  | 'exceptional'
  | 'voluntary';

export type AmountMode = 'fixed' | 'free';

export type CampaignStatus = 'draft' | 'active' | 'closed' | 'cancelled';

export interface CampaignSummary {
  membersCount: number;
  expected: number;
  collected: number;
  remaining: number;
  /** `null` pour une cotisation à montant libre : le taux n'a pas de sens. */
  recoveryRate: number | null;
  paidCount: number;
  partialCount: number;
  pendingCount: number;
  lateCount: number;
  exemptedCount: number;
}

export interface ContributionCampaign {
  id: string;
  organizationId: string;
  tontineId: string | null;
  cashboxId: string | null;
  title: string;
  description: string | null;
  contributionType: ContributionType;
  amount: number;
  amountMode: AmountMode;
  currency: string;
  startDate: string | null;
  dueDate: string | null;
  mandatory: boolean;
  penaltyEnabled: boolean;
  penaltyAmount: number;
  status: CampaignStatus;
  createdBy: string | null;
  createdAt: string;
  updatedAt: string;
  closedAt: string | null;
  summary?: CampaignSummary;
  entries?: CampaignEntry[];
}

export interface CampaignPayload {
  title: string;
  description?: string | null;
  contributionType: ContributionType;
  amount: number;
  amountMode: AmountMode;
  dueDate?: string | null;
  memberIds?: string[] | null;
  cashboxId?: string | null;
  mandatory?: boolean;
  penaltyEnabled?: boolean;
  penaltyAmount?: number;
}

export type CampaignEntryStatus =
  | 'pending'
  | 'partial'
  | 'paid'
  | 'late'
  | 'exempted'
  | 'cancelled';

export interface CampaignEntry {
  id: string;
  organizationId: string;
  campaignId: string;
  memberId: string;
  memberName: string;
  expectedAmount: number;
  paidAmount: number;
  remainingAmount: number;
  dueDate: string | null;
  status: CampaignEntryStatus;
  lastPaymentAt: string | null;
  exemptionReason: string | null;
  daysLate: number;
  payments?: CampaignPaymentRecord[];
  /** Présents seulement dans la vue « Impayés ». */
  campaignTitle?: string;
  contributionType?: ContributionType;
}

export interface CampaignPaymentRecord {
  id: string;
  organizationId: string;
  entryId: string;
  cashTransactionId: string | null;
  amount: number;
  paymentMethod: string;
  reference: string | null;
  comment: string | null;
  attachmentId: string | null;
  status: string;
  recordedBy: string | null;
  paidAt: string | null;
  confirmedAt: string | null;
  cancelledAt: string | null;
  cancelReason: string | null;
}

export interface CampaignPaymentPayload {
  amount: number;
  paymentMethod: string;
  reference?: string | null;
  comment?: string | null;
  paidAt?: string | null;
}

/** Les quatre nombres qui ne doivent jamais se confondre, plus les caisses. */
export interface FinancialDashboard {
  cashBalance: number;
  cashboxes: Cashbox[];
  cashboxCount: number;
  monthInflows: number;
  monthOutflows: number;
  expected: number;
  collected: number;
  remaining: number;
  lateAmount: number;
  recoveryRate: number | null;
  treasury: TreasurySnapshot;
}
