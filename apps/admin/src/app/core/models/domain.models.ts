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
  transactions: CashTransaction[];
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
