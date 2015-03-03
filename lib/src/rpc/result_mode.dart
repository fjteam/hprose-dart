/**********************************************************\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: http://www.hprose.com/                 |
|                   http://www.hprose.org/                 |
|                                                          |
\**********************************************************/
/**********************************************************\
 *                                                        *
 * result_mode.dart                                       *
 *                                                        *
 * hprose result mode for Dart.                           *
 *                                                        *
 * LastModified: Mar 3, 2015                              *
 * Author: Ma Bingyao <andot@hprose.com>                  *
 *                                                        *
\**********************************************************/
part of hprose.rpc;

const int Normal = 0;
const int Serialized = 1;
const int Raw = 2;
const int RawWithEndTag = 3;