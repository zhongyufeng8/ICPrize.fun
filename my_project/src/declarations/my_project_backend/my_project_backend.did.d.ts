import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface Bet { 'user' : string, 'timestamp' : Time, 'amount' : bigint }
export interface Message {
  'content' : string,
  'sender' : string,
  'timestamp' : Time,
}
export interface Pool {
  'id' : string,
  'lastBetTime' : [] | [Time],
  'status' : PoolStatus,
  'creator' : string,
  'token' : TokenInfo,
  'betAmount' : bigint,
  'bets' : Array<Bet>,
  'createdAt' : Time,
  'totalAmount' : bigint,
  'initialAmount' : bigint,
  'winnerCount' : bigint,
}
export type PoolStatus = { 'Active' : null } |
  { 'Completed' : null } |
  { 'Canceled' : null };
export type Result = { 'ok' : null } |
  { 'err' : string };
export type Result_1 = { 'ok' : string } |
  { 'err' : string };
export type Result_2 = { 'ok' : TokenInfo } |
  { 'err' : string };
export type Time = bigint;
export interface TokenInfo {
  'fee' : bigint,
  'decimals' : number,
  'logo' : [] | [string],
  'ledger' : string,
  'symbol' : string,
}
export type TransferResult = { 'ok' : bigint } |
  { 'err' : string };
export interface _SERVICE {
  'addToken' : ActorMethod<[string], Result_2>,
  'createPool' : ActorMethod<[string, bigint, bigint, bigint], Result_1>,
  'getActivePools' : ActorMethod<[], Array<Pool>>,
  'getAllTokenSymbols' : ActorMethod<[], Array<string>>,
  'getAllTokens' : ActorMethod<[], Array<TokenInfo>>,
  'getCountdown' : ActorMethod<[string], [] | [bigint]>,
  'getLatestMessages' : ActorMethod<[bigint], Array<Message>>,
  'getMinimumBet' : ActorMethod<[string], [] | [bigint]>,
  'getPool' : ActorMethod<[string], [] | [Pool]>,
  'getSystemInfo' : ActorMethod<[], string>,
  'getToken' : ActorMethod<[string], [] | [TokenInfo]>,
  'hasNewMessages' : ActorMethod<[], boolean>,
  'healthCheck' : ActorMethod<[], boolean>,
  'placeBet' : ActorMethod<[string], Result>,
  'sendMessage' : ActorMethod<[string], undefined>,
  'settlePool' : ActorMethod<[string], Result>,
  'transferToken' : ActorMethod<[string, string, bigint], TransferResult>,
  'updateLastMessageCheck' : ActorMethod<[], undefined>,
}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
