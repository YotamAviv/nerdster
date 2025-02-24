import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// How embarrassing! 
/// I had a bug back somewhere around 2024-09-15T20:40:08.537255Z that lead to 2 statements in my data with that exact same date.
/// For better or worse, the order served by Firebase sorted by time always provided the 2 statements in a favorable order, and so I didn't notice until recently.
/// My options included: 
/// 1) ignoring the data corruption and hope that Firebase sort remains favorable, 
/// 2) replacing my key, 
/// 3) backdate all of my statements. (selected)
/// 
/// This file is checked in cuz why not.
/// 
/// Here are my notes and stuff from that day:
/// 
/// Plan
/// Emulator:
/// - save to this file
///   - http://127.0.0.1:5002/one-of-us-net/us-central1/export3?token=2c3142d16cac3c5aeb6d7d40a4ca6beb7bd92431
///     - this required local changes to keep "I", and "statement"
///   - my ONE-OF-US private key 
/// 
/// - run UI (local machine, local code changes, emulator)
/// - manually delete my collection (Firebase console on emulator)
/// - call fix from DEV menu
/// - fix writes my new collection
/// - look around and verify
/// 
/// PROD:
/// - backup
/// - use PROD
/// - same as above

List<Json> input = [
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "M7l7bQBumX2Z-Rhh8M2nvgupd65ZwNn8x0uHY7H5bRY"
    },
    "with": {
      "moniker": "Eyal F"
    },
    "previous": "bf020f1641972aed5cbd4c6c040f78e5d936e105",
    "signature": "268613a844523fe8682ced911f724df04d9502056dd172ffa6b5b9dec5ee9d29ffc5748d71da3c8625511a928f97ae0639b8c4e1321135d964b36c588f718907",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2025-02-17T14:22:24.842019Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "bYhOIKTEqwDe1tmlrtDAtSw9EPeXl_tto5euQpt_v50"
    },
    "with": {
      "moniker": "Dave A"
    },
    "previous": "0b722db7792bded22aac2e15f96252b93697f44d",
    "signature": "c76b5b44c0ef7a6705f06027cedfaf0ef29dc7d6a5ecca715c78f3587dfda9a188f1f318bd66c94798d5b3a93b585dd4f2b54aa3b5004b153174cf8c235a5005",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2025-02-17T13:26:50.994021Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "zzWDiUybV6Yj7Fp-frynBZbwHGaL8EDe18NB1DJebp4"
    },
    "with": {
      "moniker": "Mateo"
    },
    "previous": "23312edb46f928221108d381e9f495a27dd14bea",
    "signature": "b814b00e2dd9821517c9cff9473d919f9c5700889f30d7fc1bdb86037dba6632ad4ac825340783fca3f0504b417562d9cd7ce0c7ed05145de0e960cfcba27501",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-12-16T14:16:45.852751Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "2gHnIE6_rm53Q3ktKlih7kjWncPJV3Qc-dtfm3vJsT8"
    },
    "with": {
      "moniker": "A J"
    },
    "previous": "2ff10a011565945334dade51c83aa05341273d7b",
    "signature": "85ae367e0a334c3f44b710cd2af2d93583c18de334176412a6f21a086cb4d9ecf894a43c0785c1a560483fdb96f567e14f48906be7e7292115cb3d7589dc1705",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-12-06T03:23:59.746485Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "-FHOdDNxrUFw2EGCeZiTPIWjK8tn2AsgJL59FqABw2s"
    },
    "with": {
      "moniker": "Jason"
    },
    "previous": "7dc02478bd9b833aa2796b92eaa27a4f7ac04268",
    "signature": "4b76018eb47217a4cd31dc15e3046623c2f1b84d16e1c99e687fd75fac8d64365c02a06c0a596e1f4d109ef37531ed4401c9bfb45e004f27a0bb4229855d8000",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-12-02T20:07:10.834537Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "G1_KSd2E-V62L8tQIFNmdk2sObHxYAAmk8gVtHQDf84"
    },
    "with": {
      "moniker": "James"
    },
    "previous": "5567c965d7d5991e7045227caed8e7e54df85ecf",
    "signature": "9b507226a002e8ad541b23b6627589453586f7626dbf7c0f9b508f3416e28bfa7ccac2fca6a1386cf5f1c82cb96a175887c9106498ca5cb39d0ceaf180c6140c",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-11-27T22:33:58.542104Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "-bxsrml3jcHQdscHhruRyrP97SGT1J-jJMKD7cRCPKw"
    },
    "with": {
      "moniker": "Hillel M"
    },
    "previous": "81f9855ab455df464c413ab462c2edf897315848",
    "signature": "9f7706062ea3c01eb3819e9e2370e4a3f8e11af069da2cc70f19c2673c1a1ee0a876fd20bbf4a84c050cc7ffb9ebd7ec9cff7e92794b236b81251640677ab507",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "comment": "former colleague\na true and loyal friend",
    "time": "2024-11-27T18:11:04.748412Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "o4fdtWGHNblOhMHDYgoYX4Vi86k9AGUTpcZHfZHZEOQ"
    },
    "with": {
      "moniker": "Andrew"
    },
    "previous": "5fc49aef05ba0ef6f9a547de0f1857aaf596371a",
    "signature": "9c896b3be4bb055c990af31fee594cc9e4343a73651bb546c4fa2b68a7da2f6a1d50f510e5ac43cf4b09955fbaed2aae8b4f3ab2d56552af915eb75ae284ee04",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-11-17T23:18:36.226803Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "0b2c56f59114dd47f5f394810ee60b7a5da1fe61",
    "signature": "b8f7b5b39f47920b2842d80114e8cdf23c33d61b2b995490cfc665244212acbcd3ddc5f77cff47eca0a1b42b33a6564ebe4d8bb00d0d01922f6b9fe61589480d",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "comment": "cousin",
    "time": "2024-10-22T15:43:40.475401Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "LxcgcUEK-djXUcMRg2qJSd00hqw89EP0Pc9iocw2UcE"
    },
    "with": {
      "moniker": "Dave"
    },
    "previous": "ab00bf4de0b0cd54b34e0ab7270ea007e2064c02",
    "signature": "be1b5c9c56b38d71e9f319fca67b755d97a398f44090a2126cf0808603cc5f1a9f1e83a6172e36b25683ab4cfc759872950dbf796a8b0cb3ade3c163b4d1ff0e",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-10-21T14:36:56.162455Z"
  },
  {
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "3d04f603614e07cf7cc6dad7405cdb322f0a3570",
    "signature": "6e7ec51039fa9cbf741d3ca08d766486547f8e1604961717cdf94c9d99e698a14368c6c52f3a55c7b1eae84b9af8e00d97637a1f8c1fa4471ee91225eb554109",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "time": "2024-10-18T17:24:13.692677Z"
  },
  {
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "_Gy7YmUG6FR0e2J2Drojz72Kv6yyHVVlJOHHoH6apdQ"
    },
    "with": {
      "moniker": "Hillel TT"
    },
    "previous": "a6ff811ff25f0a3b69e45627f8a3e30df940abce",
    "signature": "5bcef98df422ca1117244a618b4c5bac998bc04ae7b45d6d0af2299f43786ee37e018fd1130c5f59b365ac40fa205744e569cb277ef77e326fba4a3f1047d306",
    "statement": "net.one-of-us",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "comment": "cousin",
    "time": "2024-09-13T17:27:02.004843Z"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-08-11T00:55:03.109Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "444b245d7e6dbc8cfbf7393a4e23cfaae3dda80b",
    "signature": "b736d33c5f946882477ee6004b1e972d38ace0a7ff7189b20cf87c691821469807f87f3efd7b29bc6ba8a7284ed89031f9b129dd319f1f275dc217901e7cb90a"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-08-11T00:55:01.565Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org",
      "moniker": "yotam-nerdster0"
    },
    "signature": "7b72d1e417781b9cba35414aaa5624fdae7cfa026fb08337c9b883b310e17ce0fe9d3fd4e4d03366b87d756033c8d4b51a3604351b78b35b0c1fd395c4597c0d",
    "comment": "nerdster key"
  }];

List<Json> corruption = [
  {
    "statement": "net.one-of-us",
    "time": "2025-02-17T14:22:24.842019Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "M7l7bQBumX2Z-Rhh8M2nvgupd65ZwNn8x0uHY7H5bRY"
    },
    "with": {
      "moniker": "Eyal F"
    },
    "previous": "bf020f1641972aed5cbd4c6c040f78e5d936e105",
    "signature": "268613a844523fe8682ced911f724df04d9502056dd172ffa6b5b9dec5ee9d29ffc5748d71da3c8625511a928f97ae0639b8c4e1321135d964b36c588f718907"
  },
  {
    "statement": "net.one-of-us",
    "time": "2025-02-17T13:26:50.994021Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "bYhOIKTEqwDe1tmlrtDAtSw9EPeXl_tto5euQpt_v50"
    },
    "with": {
      "moniker": "Dave A"
    },
    "previous": "0b722db7792bded22aac2e15f96252b93697f44d",
    "signature": "c76b5b44c0ef7a6705f06027cedfaf0ef29dc7d6a5ecca715c78f3587dfda9a188f1f318bd66c94798d5b3a93b585dd4f2b54aa3b5004b153174cf8c235a5005"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-12-16T14:16:45.852751Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "zzWDiUybV6Yj7Fp-frynBZbwHGaL8EDe18NB1DJebp4"
    },
    "with": {
      "moniker": "Mateo"
    },
    "previous": "23312edb46f928221108d381e9f495a27dd14bea",
    "signature": "b814b00e2dd9821517c9cff9473d919f9c5700889f30d7fc1bdb86037dba6632ad4ac825340783fca3f0504b417562d9cd7ce0c7ed05145de0e960cfcba27501"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-12-14T21:35:40.504533Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "clear": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "ajiB6utLV1d7IucjxIq7my2cx4vWVP0uUM3Tw7ViWp0"
    },
    "previous": "ee694b40d93942c588af8f1c50efd763504803d4",
    "signature": "44b5511779141b0bfca6c00107f39d03ee1dc3b5ea297821f198ac046aa7dcf5dacdf7928269e4ec4ff1a6d9c3eaf9fa090746542dd0fcb75003a8f2d18af702"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-12-14T21:35:33.688570Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "clear": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "4f0ExQrCr4Xet3BofFsd08rthlDEpfw_Dy-f4utwP1A"
    },
    "previous": "54ac048a8f6cf1a4a3bccf326a48c98093ff5cc5",
    "signature": "8c9da1e8a5a49cba0d5bac5bedf1ec23e111990135995c1cad6932c910471c250d12c5f976e46336689ebbe632cd18ffbdd68f1a8a4e6e46c4f920f93f9bb70e"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-12-06T03:23:59.746485Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "2gHnIE6_rm53Q3ktKlih7kjWncPJV3Qc-dtfm3vJsT8"
    },
    "with": {
      "moniker": "A J"
    },
    "previous": "2ff10a011565945334dade51c83aa05341273d7b",
    "signature": "85ae367e0a334c3f44b710cd2af2d93583c18de334176412a6f21a086cb4d9ecf894a43c0785c1a560483fdb96f567e14f48906be7e7292115cb3d7589dc1705"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-12-02T20:07:10.834537Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "-FHOdDNxrUFw2EGCeZiTPIWjK8tn2AsgJL59FqABw2s"
    },
    "with": {
      "moniker": "Jason"
    },
    "previous": "7dc02478bd9b833aa2796b92eaa27a4f7ac04268",
    "signature": "4b76018eb47217a4cd31dc15e3046623c2f1b84d16e1c99e687fd75fac8d64365c02a06c0a596e1f4d109ef37531ed4401c9bfb45e004f27a0bb4229855d8000"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-11-27T22:33:58.542104Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "G1_KSd2E-V62L8tQIFNmdk2sObHxYAAmk8gVtHQDf84"
    },
    "with": {
      "moniker": "James"
    },
    "previous": "5567c965d7d5991e7045227caed8e7e54df85ecf",
    "signature": "9b507226a002e8ad541b23b6627589453586f7626dbf7c0f9b508f3416e28bfa7ccac2fca6a1386cf5f1c82cb96a175887c9106498ca5cb39d0ceaf180c6140c"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-11-27T18:11:04.748412Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "-bxsrml3jcHQdscHhruRyrP97SGT1J-jJMKD7cRCPKw"
    },
    "with": {
      "moniker": "Hillel M"
    },
    "previous": "81f9855ab455df464c413ab462c2edf897315848",
    "signature": "9f7706062ea3c01eb3819e9e2370e4a3f8e11af069da2cc70f19c2673c1a1ee0a876fd20bbf4a84c050cc7ffb9ebd7ec9cff7e92794b236b81251640677ab507",
    "comment": "former colleague\na true and loyal friend"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-11-17T23:18:36.226803Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "o4fdtWGHNblOhMHDYgoYX4Vi86k9AGUTpcZHfZHZEOQ"
    },
    "with": {
      "moniker": "Andrew"
    },
    "previous": "5fc49aef05ba0ef6f9a547de0f1857aaf596371a",
    "signature": "9c896b3be4bb055c990af31fee594cc9e4343a73651bb546c4fa2b68a7da2f6a1d50f510e5ac43cf4b09955fbaed2aae8b4f3ab2d56552af915eb75ae284ee04"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-11-14T15:36:27.600674Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "ajiB6utLV1d7IucjxIq7my2cx4vWVP0uUM3Tw7ViWp0"
    },
    "with": {
      "moniker": "Ville"
    },
    "previous": "6c984dfd89cd5049a111ed89c0d6ba1c601815fc",
    "signature": "8c884cfe03e42693b6434788ef324bd76fd04a5136e0ae290384e9a56816a475a14a341d7c4bbf5999bd924ec5461434fec7c0dc093ec55488910a131499860c"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-11-14T15:25:35.649774Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "4f0ExQrCr4Xet3BofFsd08rthlDEpfw_Dy-f4utwP1A"
    },
    "with": {
      "moniker": "Mike"
    },
    "previous": "3dfb37d5f7bf060950a8480a7f48ebe2a3d44f02",
    "signature": "b106d2e2ea2b35fba4323540da326afff74474f1d83e0c0e5d6ed5ca3dd0067a5e19b4d26b0b88e11dbcde2d8f2ef9795cc1f17df3085c95db49f311f0ef0c0c"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-10-24T16:18:21.096398Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "o4fdtWGHNblOhMHDYgoYX4Vi86k9AGUTpcZHfZHZEOQ"
    },
    "with": {
      "moniker": "Andrew"
    },
    "previous": "144e28a0da22fd5be0f71618b9628b1526815737",
    "signature": "ffbcbbdef147c14fa88c9149701b348fff476af2a52cdc10f6f0eba93aa987d6462695403ea68637d6e4a5e027e4c3d6cf257a2a2a56b1bd29c40f43c302b40f"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-10-22T15:43:40.475401Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "0b2c56f59114dd47f5f394810ee60b7a5da1fe61",
    "signature": "b8f7b5b39f47920b2842d80114e8cdf23c33d61b2b995490cfc665244212acbcd3ddc5f77cff47eca0a1b42b33a6564ebe4d8bb00d0d01922f6b9fe61589480d",
    "comment": "cousin"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-10-21T23:41:29.931326Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "o4fdtWGHNblOhMHDYgoYX4Vi86k9AGUTpcZHfZHZEOQ"
    },
    "with": {
      "moniker": "Andrew"
    },
    "previous": "64a26320c15a738cb8df8e190ac05cfdbde91585",
    "signature": "8f04245d7e79015d7640066912897583efa27d6e278a81cf05c1beb887fdbefc60a34c07c74cba410ae6d2ac2487eac71e5e39c3cb9969d856a1a26fd50ece03"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-10-21T14:36:56.162455Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "LxcgcUEK-djXUcMRg2qJSd00hqw89EP0Pc9iocw2UcE"
    },
    "with": {
      "moniker": "Dave"
    },
    "previous": "ab00bf4de0b0cd54b34e0ab7270ea007e2064c02",
    "signature": "be1b5c9c56b38d71e9f319fca67b755d97a398f44090a2126cf0808603cc5f1a9f1e83a6172e36b25683ab4cfc759872950dbf796a8b0cb3ade3c163b4d1ff0e"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-10-20T22:49:18.995550Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "o4fdtWGHNblOhMHDYgoYX4Vi86k9AGUTpcZHfZHZEOQ"
    },
    "with": {
      "moniker": "Andrew"
    },
    "previous": "04a4511d6877fb9dd03c0d3f4399c257c0445d09",
    "signature": "52a20cd0140d4d54ca331fe776f78f5f48d1b122509df3abc16bd161cba0cc41fef7d40ed67a5b2af05a0995c05e4386c532220ebdd419e24b02e4914dec280f"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-10-18T22:06:16.672683Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "99ffd885746303956d6cc479e7f52cb988663630",
    "signature": "8affdc94c831713ea1accb16a3e6dd06814dffcd407ce993f3969878d2634978e5d8bccc147572a6b28d2f97590705a5c859b2df9084f968a4cc45bc480acc02",
    "comment": "cousin"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-10-18T17:24:13.692677Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "3d04f603614e07cf7cc6dad7405cdb322f0a3570",
    "signature": "6e7ec51039fa9cbf741d3ca08d766486547f8e1604961717cdf94c9d99e698a14368c6c52f3a55c7b1eae84b9af8e00d97637a1f8c1fa4471ee91225eb554109"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-10-18T17:23:52.559379Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "f40984759a9ad111afd870d6ec975acf527702a1",
    "signature": "27c05223b3115287fc59bca76a56f9de3a431143201e0d3f347272c409793f3dddfa919cee402a7f675a709761cb12e86c06f9705f9f85e08d207064282dd804",
    "comment": "cousin (still, again)"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:30:10.046115Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "clear": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "T82qNt8mF7LkddmOy43Fr52v9Ca2btT8S0hFmleHzIk"
    },
    "previous": "1160a1fe1b7861dbfa14ad7c91167c780095964d",
    "signature": "fc2fb980982dc1dff7d9dab1ec5593d4189fe0de94aa1e87eebefafb487d7d70450137ba484eeb903dfdfe128cd9919302dd25f58ac10724a34738560e08070f"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:28:27.576114Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "e31b56f8bf390544b9795156d0141eada9ebbe37",
    "signature": "2fd27d80515b072c0a65df904ed8fc6839d01b3271aff3ed29b2e7fe644d899f3675288d7564334d113649254b9a691b82e62596b9363f4e9922d6033272270e",
    "comment": "whoops "
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:09:30.135388Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "clear": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "previous": "9aa9419bc13144b77388d710b68182b888811a15",
    "signature": "6a225e1a25458e47dee1ab0441e4b567803af480e3f935164bead0ee4155f52f233bcc165f795d7d74b4139b3fee6c838ebdbb2ae8457bdcbacb9ca20b64be09"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:09:24.431665Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "clear": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "jw1wCEZdhmB5Wta5hsKvrk19p9UoQHGwzWFPaXNeuHQ"
    },
    "previous": "240bc63eabeb517643244927bf3668cde488ff9d",
    "signature": "6d2fc67e80cf0c0fd4dba57303c897bb428e56a540bd7ba454ab588b6c8e76775fea7efbc9ad8ddb6799366d83e3d55cb3e74652b37826d4adf06c2ba7e33a0e"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:09:19.505490Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "clear": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "NmIav5y4Lzm6xQgud9tLgHufPlwkCR6iWYnXb0rPaCg"
    },
    "previous": "58924839f04bb36117dac069b791d5fdb99e2462",
    "signature": "fc7ed826a7c5893c7fc5866f83f92a8fbeac66d831d7a572c236053edbd2b5f457933e6cabbe483bd37aaa1a30a46610a91650e3a7ae87137c36a9d2611a7602"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:09:14.397787Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "clear": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "knRVKovruzZao990vKIUYSRbJLKre0CrmiTn8QYrB8I"
    },
    "previous": "45c8bfceacf59581cf18547a523ffa0d6f184997",
    "signature": "1502a11f9c249ebfdec1a26041476fa2bcd95895db64e5a4b3a59c6b7642951cb6a2fc5c4d4af60bb8a836ec3e22695fee4abac4086a778b68d763cb1479b104"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:09:04.349279Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "T82qNt8mF7LkddmOy43Fr52v9Ca2btT8S0hFmleHzIk"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "8d2766a78934384cb31fec3602f6acf515b5d65c",
    "signature": "74f99acdd060ee75e47b593040314293bc077b3c581c1c8d984902b85f7513a2eb31c47548e73bd2660ff8cc1cca9b1e2a0054b3e131323b9b2f29be0f749208"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:08:09.143962Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "knRVKovruzZao990vKIUYSRbJLKre0CrmiTn8QYrB8I"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "58218bb9d3ec420c1d9ebe76251ac73f92354016",
    "signature": "e06601378c2ad1e8fe4d7da6ab05bc9363b87f81804adc60035b829d592895ab682bd107204e8d86f796c8b27e8ac1e01f73f246df00680b4326ba48c8908602"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:07:55.127911Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "NmIav5y4Lzm6xQgud9tLgHufPlwkCR6iWYnXb0rPaCg"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "70dc22ca555945b77feee270eaa3b9facbc3b045",
    "signature": "6d637aed4e3318534fa2b73c16e488304be978edbafc54c8f753188206644af0eae508eca573feb9c0b6a095de624f47975e39eb91d4ed1a448458e6a9c7da02"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-16T17:07:44.030740Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "jw1wCEZdhmB5Wta5hsKvrk19p9UoQHGwzWFPaXNeuHQ"
    },
    "with": {
      "domain": "sdf"
    },
    "previous": "7e3464d29304d3fd10084c12a788779ebf8bd59f",
    "signature": "a1c205f53ae57defb7fb4b602243e5a8ae85d8a3e04adc56a57e7bedea4fd69a8fdf690b33d3245279e875cfbd09e01a7d9540941075b4ee0ef71737525d780b"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-15T20:40:08.537255Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "537103a5b6b77878c89beae218dfb0e5eafd21de",
    "signature": "1a99d48d14df45fef0dad03cf12d43af5d3646b0fde2c4addb5266cee2320a3cb026afd0645d45a6443417e2497e47918ab1b9d841dd194075bfa5a08a0e630f",
    "comment": "cousin (still, again)"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-15T20:40:08.537255Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "3bf1662d36192f24393bf096fca3a28c40bce5ac",
    "signature": "0fcbce54b976583c756c028f77eea2529855c55bf5ddca66e450844770b57ca54305b05da367582eec31cdfe0e6ef93b861e79a0cd84de0b434479aadf815c09",
    "comment": "cousin (still, again)"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-15T17:35:52.503773Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "d25a5a034bee66ed7cf144207828f37767cbfde5",
    "signature": "261acb739bcf680f06cf85eb3aae6def33889f7b946cd0ecaada6d8530ece239f7ed0670a58c7b17caed1c7f904c5760f8ba5a341033ddae9523093ef6b86509",
    "comment": "cousin (still)"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-13T17:27:02.004843Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "_Gy7YmUG6FR0e2J2Drojz72Kv6yyHVVlJOHHoH6apdQ"
    },
    "with": {
      "moniker": "Hillel TT"
    },
    "previous": "a6ff811ff25f0a3b69e45627f8a3e30df940abce",
    "signature": "5bcef98df422ca1117244a618b4c5bac998bc04ae7b45d6d0af2299f43786ee37e018fd1130c5f59b365ac40fa205744e569cb277ef77e326fba4a3f1047d306",
    "comment": "cousin"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-10T17:52:28.469653Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "6f025eb1c7237111b5397c9cc1e920688d8eb9c7",
    "signature": "ee18bf50a89dc3a5777a088b6b7ccecf0b28f8053dd09adf277173f9794056306dcddb98442c5d563daad50cde9ca825fd7a965b155ce3229c77a1c8a6e9c70f"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-10T17:50:58.332740Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "_Gy7YmUG6FR0e2J2Drojz72Kv6yyHVVlJOHHoH6apdQ"
    },
    "with": {
      "moniker": "Hillel TT"
    },
    "previous": "3112c0a262507d72da08cff5052c4dd3840e3a1b",
    "signature": "c308ede024edce773f572c089fa56875b2993e28724fec46c7250da95439e607692977696640cc879656648e42384d81e725dfef3a302cdf90ec01f892754f02",
    "comment": "cousin,"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-06T02:10:00.185033Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "5557417dee734be99513b32180ce516fc0f05833",
    "signature": "93f16622fd84645be32e67f0cb9ac45db0329927153074bed9a1c2f09adb76b74576a15faf0b408531af2c495af1cc97ed72ac793df0d68d6ed188e42b635a04",
    "comment": "cousin"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-06T02:09:37.086179Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "_Gy7YmUG6FR0e2J2Drojz72Kv6yyHVVlJOHHoH6apdQ"
    },
    "with": {
      "moniker": "Hillel TT"
    },
    "previous": "a7b131f8d969933020e29dc087524783502e860c",
    "signature": "84b4378dfa19642e2264c0e33b36097185c0e4c6dda449a539c606ee62a5a492b1aba0ed34dd1018c8cfffcdd1cdcc0fbf08f5bd4949027940f7fb357ec9a00c",
    "comment": "cousin"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-04T17:26:56.079380Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "bf59921ad92e63c2088a38b550027ff65d824455",
    "signature": "b4684d990e013a7928f4cb4429d9862945eb229a9eb071b6fd955f59a37656a5a5b5a6f4d92c752e51d0b469c59b0ad78cc4b04f77ee2ce82d55722972e4080f",
    "comment": "nerdster key\nUpdated on Chromebook"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-03T12:14:48.892292Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "_Gy7YmUG6FR0e2J2Drojz72Kv6yyHVVlJOHHoH6apdQ"
    },
    "with": {
      "moniker": "Hillel T"
    },
    "previous": "e63dc8136046f98e994382f1b7ae235ef8a7882f",
    "signature": "06d7c3c0be81bac0eae9ffcf5a2608e76a133d0aff67c7e0b8dd83dabae7e7e0794f83c4ad41d066b1b345859165bd6c6b9e5c6e39be1cbcf85a1a63a7164500",
    "comment": "cousin"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-03T03:04:45.343361Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "053b061b7e6a0c063314fa10b01c9a350ef6aed3",
    "signature": "e69cbd6738c62459c50616347d168d4f5b3644d797ac1f06efe44bf48e6220d1e0b8ef4aa2e8799473011d4c84bbf88b6d71de5a9b8dcbd4230adfee387ff90e",
    "comment": "Family. \nKey exchange over email."
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-09-02T01:14:30.241840Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org"
    },
    "previous": "e5a8f01fcfd0e8edc5ea12821a1adbdc74d20f78",
    "signature": "3d160fa51098eab85720ff37cd789f5df0ab8f8153ad9e1270b3d65e5d76ee349521cb17f344a8089bba6e36e5c00c5ec45e9a96f330f00833b4d684c434cb05",
    "comment": "nerdster key"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-08-15T20:20:54.044771Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "29daca188db0f96c4ce146d3e459ac7ef6bdbf3c",
    "signature": "08f323780d4d9991eafe84c39d7766fac02734b416e2ec6b52d331a70b2ec48ad1afb15a18661e2a36c9a6baba93643a5828d49740717c2f67cf48fccfce500e",
    "comment": "Family in Israel, key exchange over email.\nupdated comment on Android"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-08-15T20:13:57.186359Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "43b9acdf090eb325981741b897fd35833a9f8203",
    "signature": "90a0cdd97fa44576a419f997a4117e73eb222abc7115efdac77d09b02e30b1e1be500e1e6f54aa91703ef31ff80287fe1a62c3d8c8522b1cebd417fa0c480d0e",
    "comment": "updated comment on Android"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-08-11T00:55:03.109Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "trust": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "EHc37KRjukpvoSOT-zeExg8q54qsifRBEEr8vq5FW-c"
    },
    "with": {
      "moniker": "Amotz"
    },
    "previous": "444b245d7e6dbc8cfbf7393a4e23cfaae3dda80b",
    "signature": "b736d33c5f946882477ee6004b1e972d38ace0a7ff7189b20cf87c691821469807f87f3efd7b29bc6ba8a7284ed89031f9b129dd319f1f275dc217901e7cb90a"
  },
  {
    "statement": "net.one-of-us",
    "time": "2024-08-11T00:55:01.565Z",
    "I": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
    },
    "delegate": {
      "kty": "OKP",
      "crv": "Ed25519",
      "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"
    },
    "with": {
      "domain": "nerdster.org",
      "moniker": "yotam-nerdster0"
    },
    "signature": "7b72d1e417781b9cba35414aaa5624fdae7cfa026fb08337c9b883b310e17ce0fe9d3fd4e4d03366b87d756033c8d4b51a3604351b78b35b0c1fd395c4597c0d",
    "comment": "nerdster key"
  }
];

Json yotamKeyPair = {
  // missing
};

class Fix {
  static Future<void> fix() async {
    
    OouKeyPair keyPair = await crypto.parseKeyPair(yotamKeyPair);
    OouPublicKey publicKey = await keyPair.publicKey;
    String yotamToken = getToken(await publicKey.json);
    Fetcher fetcher = Fetcher(yotamToken, kOneofusDomain);
    OouSigner signer = await OouSigner.make(keyPair);
    String? previous;
    for (Json json in input.reversed) {
      json = Map.from(json);
      json.remove('signature');
      json.remove('previous');
      if (previous != null) json['previous'] = previous;

      Jsonish jsonish = await fetcher.push(json, signer);
      previous = jsonish.token;

      print('.');
    }
    print('fix done.');
  }
}