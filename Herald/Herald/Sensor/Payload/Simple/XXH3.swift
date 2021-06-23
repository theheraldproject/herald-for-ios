//
//  XXH3.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//
//  Adapted from xxHash-Swift created by Daisuke T
//  Copyright © 2019 xxHash-Swift. All rights reserved.
//

import Foundation
import CoreFoundation

/// XXH3 class
public typealias xxHash3 = XXH3
public class XXH3 {
    /// XXH3 Common class
    final class Common {
    }
    /// XXH3 64bit class
    final class Bit64 {
    }
}

// MARK: - 64 bit
extension XXH3 {
    
    static public func digest64(_ array: [UInt8], seed: UInt64 = 0) -> UInt64 {
        return XXH3.Bit64.digest(array, seed: seed, endian: xxHash.Common.endian())
    }
    
    static public func digest64(_ string: String, seed: UInt64 = 0) -> UInt64 {
        return XXH3.Bit64.digest(Array(string.utf8), seed: seed, endian: xxHash.Common.endian())
    }
    
    static public func digest64(_ data: Data, seed: UInt64 = 0) -> UInt64 {
        return XXH3.Bit64.digest([UInt8](data), seed: seed, endian: xxHash.Common.endian())
    }
    
    static public func digest64Hex(_ array: [UInt8], seed: UInt64 = 0) -> String {
        let h = XXH3.Bit64.digest(array, seed: seed, endian: xxHash.Common.endian())
        return xxHash.Common.UInt64ToHex(h)
    }
    
    static public func digest64Hex(_ string: String, seed: UInt64 = 0) -> String {
        let h = XXH3.Bit64.digest(Array(string.utf8), seed: seed, endian: xxHash.Common.endian())
        return xxHash.Common.UInt64ToHex(h)
    }
    
    static public func digest64Hex(_ data: Data, seed: UInt64 = 0) -> String {
        let h = XXH3.Bit64.digest([UInt8](data), seed: seed, endian: xxHash.Common.endian())
        return xxHash.Common.UInt64ToHex(h)
    }
    
}


extension XXH3.Common {
    
    // MARK: - Enum, Const
    static let keySetDefaultSize = 48 // minimum 32
    
    // swiftlint:disable comma
    static let keySet: [UInt32] = [
        0xb8fe6c39, 0x23a44bbe, 0x7c01812c, 0xf721ad1c,
        0xded46de9, 0x839097db, 0x7240a4a4, 0xb7b3671f,
        0xcb79e64e, 0xccc0e578, 0x825ad07d, 0xccff7221,
        0xb8084674, 0xf743248e, 0xe03590e6, 0x813a264c,
        0x3c2852bb, 0x91c300cb, 0x88d0658b, 0x1b532ea3,
        0x71644897, 0xa20df94e, 0x3819ef46, 0xa9deacd8,
        0xa8fa763f, 0xe39c343f, 0xf9dcbbc7, 0xc70b4f1d,
        0x8a51e04b, 0xcdb45931, 0xc89f7ec9, 0xd9787364,
        
        0xeac5ac83, 0x34d3ebc3, 0xc581a0ff, 0xfa1363eb,
        0x170ddd51, 0xb7f0da49, 0xd3165526, 0x29d4689e,
        0x2b16be58, 0x7d47a1fc, 0x8ff8b8d1, 0x7ad031ce,
        0x45cb3a8f, 0x95160428, 0xafd7fbca ,0xbb4b407e,
    ]
    // swiftlint:enable comma
    
    private static let stripeLen = 64
    private static let stripeElts = stripeLen / MemoryLayout<UInt32>.size
    private static let accNB = stripeLen / MemoryLayout<UInt64>.size
    
}


// MARK: - Utility
extension XXH3.Common {
    
    static func avalanche(_ h: UInt64) -> UInt64 {
        var h2 = h
        h2 ^= h2 >> 37
        h2 &*= XXH64.prime3
        h2 ^= h2 >> 32
        
        return h2
    }
    
    static func mult32To64(_ x: UInt32, y: UInt32) -> UInt64 {
        return UInt64(x) * UInt64(y)
    }
    
    static func mul128Fold64(ll1: UInt64, ll2: UInt64) -> UInt64 {
        let h1 = UInt32(ll1 >> 32)
        let h2 = UInt32(ll2 >> 32)
        let l1 = UInt32(ll1 & 0x00000000FFFFFFFF)
        let l2 = UInt32(ll2 & 0x00000000FFFFFFFF)
        
        let llh: UInt64 = mult32To64(h1, y: h2)
        let llm1: UInt64 = mult32To64(l1, y: h2)
        let llm2: UInt64 = mult32To64(h1, y: l2)
        let lll: UInt64 = mult32To64(l1, y: l2)
        
        let t = UInt64(lll &+ (llm1 << 32))
        let carry1 = UInt64((t < lll) ? 1 : 0)
        
        let lllow = UInt64(t &+ (llm2 << 32))
        let carry2 = UInt64((lllow < t) ? 1 : 0)
        
        let llm1l = UInt64(llm1 >> 32)
        let llm2l = UInt64(llm2 >> 32)
        
        let llhigh = UInt64(llh &+ (llm1l + llm2l + carry1 + carry2))
        
        return llhigh ^ lllow
    }
    
    // swiftlint:disable function_parameter_count
    static private func accumulate512(_ acc: inout [UInt64],
                                      array: [UInt8],
                                      arrayIndex: Int,
                                      keySet: [UInt32],
                                      keySetIndex: Int,
                                      endian: xxHash.Common.Endian) {
        // swiftlint:enable function_parameter_count
        for i in 0..<accNB {
            let dataVal: UInt64 = xxHash.Common.UInt8ArrayToUInt(array,
                                                                 index: arrayIndex + (i * 8),
                                                                 endian: endian)
            let keyVal = xxHash.Common.UInt32ToUInt64(keySet[keySetIndex + (i * 2)],
                                                      val2: keySet[keySetIndex + (i * 2) + 1],
                                                      endian: endian)
            let dataKey = UInt64(keyVal ^ dataVal)
            let mul = mult32To64(UInt32(dataKey & 0x00000000FFFFFFFF),
                                 y: UInt32(dataKey >> 32))
            acc[i] &+= mul
            acc[i] &+= dataVal
        }
    }
    
    // swiftlint:disable function_parameter_count
    static private func accumulate(_ acc: inout [UInt64],
                                   array: [UInt8],
                                   arrayIndex: Int,
                                   keySet: [UInt32],
                                   keySetIndex: Int,
                                   nbStripes: Int,
                                   endian: xxHash.Common.Endian) {
        // swiftlint:enable function_parameter_count
        for i in 0..<nbStripes {
            accumulate512(&acc,
                          array: array,
                          arrayIndex: arrayIndex + (i * stripeLen),
                          keySet: keySet,
                          keySetIndex: keySetIndex + (i * 2),
                          endian: endian)
        }
    }
    
    static private func scrambleAcc(_ acc: inout [UInt64],
                                    keySet: [UInt32],
                                    keySetIndex: Int,
                                    endian: xxHash.Common.Endian) {
        for i in 0..<accNB {
            let key64 = xxHash.Common.UInt32ToUInt64(keySet[keySetIndex + (i * 2)],
                                                     val2: keySet[keySetIndex + (i * 2) + 1],
                                                     endian: endian)
            var acc64 = acc[i]
            acc64 ^= acc64 >> 47
            acc64 ^= key64
            acc64 &*= UInt64(XXH32.prime1)
            acc[i] = acc64
        }
    }
    
    static func hashLong(_ acc: [UInt64], array: [UInt8], endian: xxHash.Common.Endian) -> [UInt64] {
        let nbKeys = (keySetDefaultSize - stripeElts) / 2
        let blockLen = stripeLen * nbKeys
        let nbBlocks = array.count / blockLen
        var acc = acc
        
        for i in 0..<nbBlocks {
            accumulate(&acc,
                       array: array,
                       arrayIndex: i * blockLen,
                       keySet: keySet,
                       keySetIndex: 0,
                       nbStripes: nbKeys,
                       endian: endian)
            
            scrambleAcc(&acc,
                        keySet: keySet,
                        keySetIndex: keySetDefaultSize - stripeElts,
                        endian: endian)
        }
        
        
        // last partial block
        let nbStripes = (array.count % blockLen) / stripeLen
        accumulate(&acc,
                   array: array,
                   arrayIndex: nbBlocks * blockLen,
                   keySet: keySet,
                   keySetIndex: 0,
                   nbStripes: nbStripes,
                   endian: endian)
        
        // last stripe
        if (array.count & (stripeLen - 1)) > 0 {
            accumulate512(&acc,
                          array: array,
                          arrayIndex: array.count - stripeLen,
                          keySet: keySet,
                          keySetIndex: nbStripes * 2,
                          endian: endian)
        }
        
        return acc
    }
    
    static private func mix2Accs(_ acc: [UInt64],
                                 accIndex: Int,
                                 keySet: [UInt32],
                                 keySetIndex: Int,
                                 endian: xxHash.Common.Endian) -> UInt64 {
        let key = xxHash.Common.UInt32ToUInt64(keySet[keySetIndex + 0],
                                               val2: keySet[keySetIndex + 1],
                                               endian: endian)
        let key2 = xxHash.Common.UInt32ToUInt64(keySet[keySetIndex + 2],
                                                val2: keySet[keySetIndex + 3],
                                                endian: endian)
        
        return mul128Fold64(ll1: acc[accIndex + 0] ^ key, ll2: acc[accIndex + 1] ^ key2)
    }
    
    static func mergeAccs(_ acc: [UInt64],
                          keySet: [UInt32],
                          keySetIndex: Int,
                          start: UInt64,
                          endian: xxHash.Common.Endian) -> UInt64 {
        var result: UInt64 = start
        
        result &+= mix2Accs(acc,
                            accIndex: 0,
                            keySet: keySet,
                            keySetIndex: keySetIndex,
                            endian: endian)
        result &+= mix2Accs(acc,
                            accIndex: 2,
                            keySet: keySet,
                            keySetIndex: keySetIndex + 4,
                            endian: endian)
        result &+= mix2Accs(acc,
                            accIndex: 4,
                            keySet: keySet,
                            keySetIndex: keySetIndex + 8,
                            endian: endian)
        result &+= mix2Accs(acc,
                            accIndex: 6,
                            keySet: keySet,
                            keySetIndex: keySetIndex + 12,
                            endian: endian)
        
        return avalanche(result)
    }
    
    // swiftlint:disable function_parameter_count
    static func mix16B(_ array: [UInt8],
                       arrayIndex: Int,
                       keySet: [UInt32],
                       keySetIndex: Int,
                       seed: UInt64,
                       endian: xxHash.Common.Endian) -> UInt64 {
        // swiftlint:enable function_parameter_count
        let ll1: UInt64 = xxHash.Common.UInt8ArrayToUInt(array,
                                                         index: arrayIndex + 0,
                                                         endian: endian)
        let ll2: UInt64 = xxHash.Common.UInt8ArrayToUInt(array,
                                                         index: arrayIndex + 8,
                                                         endian: endian)
        let key = xxHash.Common.UInt32ToUInt64(keySet[keySetIndex + 0],
                                               val2: keySet[keySetIndex + 1],
                                               endian: endian)
        let key2 = xxHash.Common.UInt32ToUInt64(keySet[keySetIndex + 2],
                                                val2: keySet[keySetIndex + 3],
                                                endian: endian)
        
        return mul128Fold64(ll1: ll1 ^ (key &+ seed), ll2: ll2 ^ (key2 &- seed))
    }
    
}

// MARK: - Utility
extension XXH3.Bit64 {
    
    static private func initKey(seed: UInt64, endian: xxHash.Common.Endian) -> [UInt32] {
        var keySet2 = [UInt32](repeating: 0, count: XXH3.Common.keySet.count)
        let seed1 = UInt32(seed & 0x00000000FFFFFFFF)
        let seed2 = UInt32(seed >> 32)
        
        for i in stride(from: 0, to: XXH3.Common.keySetDefaultSize, by: 4) {
            keySet2[i + 0] = XXH3.Common.keySet[i + 0] &+ seed1
            keySet2[i + 1] = XXH3.Common.keySet[i + 1] &- seed2
            keySet2[i + 2] = XXH3.Common.keySet[i + 2] &+ seed2
            keySet2[i + 3] = XXH3.Common.keySet[i + 3] &- seed1
        }
        
        return keySet2
    }
    
    static private func len1To3(_ array: [UInt8], keySet: [UInt32], seed: UInt64) -> UInt64 {
        let c1 = UInt32(array[0])
        let c2 = UInt32(array[array.count >> 1])
        let c3 = UInt32(array[array.count - 1])
        let l1 = UInt32(c1 &+ (c2 << 8))
        let l2 = UInt32(UInt32(array.count) &+ (c3 << 2))
        let ll11: UInt64 =  XXH3.Common.mult32To64(l1 &+ UInt32(seed) &+ keySet[0],
                                                   y: l2 &+ UInt32(seed >> 32) &+ keySet[1])
        
        return  XXH3.Common.avalanche(ll11)
    }
    
    static private func len4To8(_ array: [UInt8], keySet: [UInt32], seed: UInt64, endian: xxHash.Common.Endian) -> UInt64 {
        let in1: UInt32 = xxHash.Common.UInt8ArrayToUInt(array, index: 0, endian: endian)
        let in2: UInt32 = xxHash.Common.UInt8ArrayToUInt(array, index: array.count - 4, endian: endian)
        let in64: UInt64 = UInt64(UInt64(in1) &+ (UInt64(in2) << 32))
        let key = xxHash.Common.UInt32ToUInt64(keySet[0], val2: keySet[1], endian: endian)
        let keyed: UInt64 = in64 ^ (key &+ seed)
        let mix64: UInt64 = UInt64(array.count) &+ XXH3.Common.mul128Fold64(ll1: keyed, ll2: XXH64.prime1)
        
        return XXH3.Common.avalanche(mix64)
    }
    
    static private func len9To16(_ array: [UInt8], keySet: [UInt32], seed: UInt64, endian: xxHash.Common.Endian) -> UInt64 {
        let key = xxHash.Common.UInt32ToUInt64(keySet[0], val2: keySet[1], endian: endian)
        let key2 = xxHash.Common.UInt32ToUInt64(keySet[2], val2: keySet[3], endian: endian)
        let ll1: UInt64 = xxHash.Common.UInt8ArrayToUInt(array, index: 0, endian: endian) ^ (key &+ seed)
        let ll2: UInt64 = xxHash.Common.UInt8ArrayToUInt(array, index: array.count - 8, endian: endian) ^ (key2 &- seed)
        let acc: UInt64 = UInt64(array.count) &+ (ll1 &+ ll2) &+ XXH3.Common.mul128Fold64(ll1: ll1, ll2: ll2)
        
        return XXH3.Common.avalanche(acc)
    }
    
    static private func len0To16(_ array: [UInt8], seed: UInt64, endian: xxHash.Common.Endian) -> UInt64 {
        if array.count > 8 {
            return len9To16(array, keySet: XXH3.Common.keySet, seed: seed, endian: endian)
        } else if array.count >= 4 {
            return len4To8(array, keySet: XXH3.Common.keySet, seed: seed, endian: endian)
        } else if array.count > 0 {
            return len1To3(array, keySet: XXH3.Common.keySet, seed: seed)
        }
        
        return seed
    }
    
    static private func hashLong(_ array: [UInt8], seed: UInt64, endian: xxHash.Common.Endian) -> UInt64 {
        var acc: [UInt64] = [
            seed,
            XXH64.prime1,
            XXH64.prime2,
            XXH64.prime3,
            XXH64.prime4,
            XXH64.prime5,
            UInt64(0 &- seed),
            0
        ]
        
        let keySet: [UInt32] = initKey(seed: seed, endian: endian)
        acc = XXH3.Common.hashLong(acc, array: array, endian: endian)
        
        // converge into final hash
        return XXH3.Common.mergeAccs(acc,
                                     keySet: keySet,
                                     keySetIndex: 0,
                                     start: UInt64(array.count) &* XXH64.prime1,
                                     endian: endian)
    }
    
}


extension XXH3.Bit64 {
    
    static func digest(_ array: [UInt8], seed: UInt64, endian: xxHash.Common.Endian) -> UInt64 {
        if array.count <= 16 {
            return len0To16(array, seed: seed, endian: endian)
        }
        
        var acc = UInt64(UInt64(array.count) &* XXH64.prime1)
        
        if array.count > 32 {
            
            if array.count > 64 {
                
                if array.count > 96 {
                    
                    if array.count > 128 {
                        return hashLong(array, seed: seed, endian: endian)
                    }
                    
                    acc &+= XXH3.Common.mix16B(array,
                                               arrayIndex: 48,
                                               keySet: XXH3.Common.keySet,
                                               keySetIndex: 24,
                                               seed: seed,
                                               endian: endian)
                    
                    acc &+= XXH3.Common.mix16B(array,
                                               arrayIndex: array.count - 64,
                                               keySet: XXH3.Common.keySet,
                                               keySetIndex: 28,
                                               seed: seed,
                                               endian: endian)
                }
                
                acc &+= XXH3.Common.mix16B(array,
                                           arrayIndex: 32,
                                           keySet: XXH3.Common.keySet,
                                           keySetIndex: 16,
                                           seed: seed,
                                           endian: endian)
                
                acc &+= XXH3.Common.mix16B(array,
                                           arrayIndex: array.count - 48,
                                           keySet: XXH3.Common.keySet,
                                           keySetIndex: 20,
                                           seed: seed,
                                           endian: endian)
            }
            
            acc &+= XXH3.Common.mix16B(array,
                                       arrayIndex: 16,
                                       keySet: XXH3.Common.keySet,
                                       keySetIndex: 8,
                                       seed: seed,
                                       endian: endian)
            
            acc &+= XXH3.Common.mix16B(array,
                                       arrayIndex: array.count - 32,
                                       keySet: XXH3.Common.keySet,
                                       keySetIndex: 12,
                                       seed: seed,
                                       endian: endian)
        }
        
        acc &+= XXH3.Common.mix16B(array,
                                   arrayIndex: 0,
                                   keySet: XXH3.Common.keySet,
                                   keySetIndex: 0,
                                   seed: seed,
                                   endian: endian)
        
        acc &+= XXH3.Common.mix16B(array,
                                   arrayIndex: array.count - 16,
                                   keySet: XXH3.Common.keySet,
                                   keySetIndex: 4,
                                   seed: seed,
                                   endian: endian)
        
        return XXH3.Common.avalanche(acc)
    }
    
}

final class xxHash {
    
    /// xxHash Common class
    final class Common {
    }
    
}


extension xxHash.Common {
    
    // MARK: - Enum, Const
    enum Endian {
        case little
        case big
    }
    
    
    struct State<T: FixedWidthInteger> {
        var totalLen: T = 0
        var largeLen: Bool = false
        var v1: T = 0
        var v2: T = 0
        var v3: T = 0
        var v4: T = 0
        var mem = [UInt8](repeating: 0, count: MemoryLayout<T>.size * 4)
        var memSize: Int = 0
        var reserved: T = 0    // never read nor write, might be removed in a future version
    }
    
}


// MARK: - Utility
extension xxHash.Common {
    
    static func endian() -> Endian {
        if CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) {
            return Endian.little
        }
        
        return Endian.big
    }
    
    
    static func rotl<T: FixedWidthInteger>(_ x: T, r: Int) -> T {
        return (x << r) | (x >> (T.bitWidth - r))
    }
    
}


// MARK: - Utility(Swap)
extension xxHash.Common {
    
    static func swap<T: FixedWidthInteger>(_ x: T) -> T {
        var res: T = 0
        var mask: T = 0xff
        var bit = 0
        
        bit = (MemoryLayout<T>.size - 1) * 8
        for _ in 0..<MemoryLayout<T>.size / 2 {
            res |= (x & mask) << bit
            mask = mask << 8
            bit -= 16
        }
        
        bit = 8
        for _ in 0..<MemoryLayout<T>.size / 2 {
            res |= (x & mask) >> bit
            mask = mask << 8
            bit += 16
        }
        
        return res
    }
    
}


// MARK: - Utility(Convert)
extension xxHash.Common {
    
    static func UInt8ArrayToUInt<T: FixedWidthInteger>(_ array: [UInt8], index: Int) -> T {
        var block: T = 0
        
        for i in 0..<MemoryLayout<T>.size {
            block |= T(array[index + i]) << (i * 8)
        }
        
        return block
    }
    
    static func UInt8ArrayToUInt<T: FixedWidthInteger>(_ array: [UInt8], index: Int, endian: xxHash.Common.Endian) -> T {
        var block: T = UInt8ArrayToUInt(array, index: index)
        
        if endian == xxHash.Common.Endian.little {
            return block
        }
        
        
        // Big Endian
        block = swap(block)
        
        return block
    }
    
    
    static private func UIntToUInt8Array<T: FixedWidthInteger>(_ block: T) -> [UInt8] {
        var array = [UInt8](repeating: 0, count: MemoryLayout<T>.size)
        var mask: T = 0xff
        
        for i in 0..<MemoryLayout<T>.size {
            array[i] = UInt8((block & mask) >> (i * 8))
            mask = mask << 8
        }
        
        return array
    }
    
    static func UIntToUInt8Array<T: FixedWidthInteger>(_ block: T, endian: xxHash.Common.Endian) -> [UInt8] {
        var array = UIntToUInt8Array(block)
        
        if endian == xxHash.Common.Endian.little {
            return array
        }
        
        
        // Big Endian
        array.reverse()
        
        return array
    }
    
    static func UInt32ToUInt64(_ val: UInt32, val2: UInt32, endian: xxHash.Common.Endian) -> UInt64 {
        if endian == .little {
            let h = UInt64(UInt64(val2) << 32)
            let l = UInt64(val)
            
            return h + l
        }
        
        let h = UInt64(UInt64(val) << 32)
        let l = UInt64(val2)
        
        return h + l
    }
    
    static func UInt32ToHex(_ val: UInt32) -> String {
        return String.init(format: "%08x", val)
    }
    
    static func UInt64ToHex(_ val: UInt64) -> String {
        return String.init(format: "%016lx", val)
    }
    
    static func UInt128ToHex(_ val: UInt64, val2: UInt64) -> String {
        return String.init(format: "%016lx%016lx", val, val2)
    }
}

public typealias xxHash64 = XXH64
public class XXH64 {
    
    // MARK: - Enum, Const
    static let prime1: UInt64 = 11400714785074694791    // 0b1001111000110111011110011011000110000101111010111100101010000111
    static let prime2: UInt64 = 14029467366897019727    // 0b1100001010110010101011100011110100100111110101001110101101001111
    static let prime3: UInt64 =  1609587929392839161    // 0b0001011001010110011001111011000110011110001101110111100111111001
    static let prime4: UInt64 =  9650029242287828579    // 0b1000010111101011110010100111011111000010101100101010111001100011
    static let prime5: UInt64 =  2870177450012600261    // 0b0010011111010100111010110010111100010110010101100110011111000101
    
    
    
    // MARK: - Property
    private let endian = xxHash.Common.endian()
    private var state = xxHash.Common.State<UInt64>()
    
    /// A seed for generate digest. Default is 0.
    public var seed: UInt64 {
        didSet {
            reset()
        }
    }
    
    
    
    // MARK: - Life cycle
    
    /// Creates a new instance with the seed.
    ///
    /// - Parameter seed: A seed for generate digest. Default is 0.
    public init(_ seed: UInt64 = 0) {
        self.seed = seed
        reset()
    }
    
}



// MARK: - Utility
extension XXH64 {
    
    static private func round(_ acc: UInt64, input: UInt64) -> UInt64 {
        var acc2 = acc
        acc2 &+= input &* prime2
        acc2 = xxHash.Common.rotl(acc2, r: 31)
        acc2 &*= prime1
        
        return acc2
    }
    
    static private func mergeRound(_ acc: UInt64, val: UInt64) -> UInt64 {
        let val2 = round(0, input: val)
        var acc2 = acc ^ val2
        acc2 = acc2 &* prime1 &+ prime4
        
        return acc2
    }
    
    static private func avalanche(_ h: UInt64) -> UInt64 {
        var h2 = h
        h2 ^= h2 >> 33
        h2 &*= prime2
        h2 ^= h2 >> 29
        h2 &*= prime3
        h2 ^= h2 >> 32
        
        return h2
    }
}



// MARK: - Finalize
extension XXH64 {
    
    static private func finalize(_ h: UInt64, array: [UInt8], len: Int, endian: xxHash.Common.Endian) -> UInt64 {
        var index = 0
        var h2 = h
        
        func process1() {
            h2 ^= UInt64(array[index]) &* prime5
            index += 1
            h2 = xxHash.Common.rotl(h2, r: 11) &* prime1
        }
        
        func process4() {
            h2 ^= UInt64(xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian) as UInt32) &* prime1
            index += 4
            h2 = xxHash.Common.rotl(h2, r: 23) &* prime2 &+ prime3
        }
        
        func process8() {
            let k1 = round(0, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
            index += 8
            h2 ^= k1
            h2 = xxHash.Common.rotl(h2, r: 27) &* prime1 &+ prime4
        }
        
        
        switch len & 31 {
        case 24:
            process8()
            fallthrough
            
        case 16:
            process8()
            fallthrough
            
        case 8:
            process8()
            return avalanche(h2)
            
            
        case 28:
            process8()
            fallthrough
            
        case 20:
            process8()
            fallthrough
            
        case 12:
            process8()
            fallthrough
            
        case 4:
            process4()
            return avalanche(h2)
            
            
        case 25:
            process8()
            fallthrough
            
        case 17:
            process8()
            fallthrough
            
        case 9:
            process8()
            process1()
            return avalanche(h2)
            
            
        case 29:
            process8()
            fallthrough
            
        case 21:
            process8()
            fallthrough
            
        case 13:
            process8()
            fallthrough
            
        case 5:
            process4()
            process1()
            return avalanche(h2)
            
            
        case 26:
            process8()
            fallthrough
            
        case 18:
            process8()
            fallthrough
            
        case 10:
            process8()
            process1()
            process1()
            return avalanche(h2)
            
            
        case 30:
            process8()
            fallthrough
            
        case 22:
            process8()
            fallthrough
            
        case 14:
            process8()
            fallthrough
            
        case 6:
            process4()
            process1()
            process1()
            return avalanche(h2)
            
            
        case 27:
            process8()
            fallthrough
            
        case 19:
            process8()
            fallthrough
            
        case 11:
            process8()
            process1()
            process1()
            process1()
            return avalanche(h2)
            
            
        case 31:
            process8()
            fallthrough
            
        case 23:
            process8()
            fallthrough
            
        case 15:
            process8()
            fallthrough
            
        case 7:
            process4()
            fallthrough
            
        case 3:
            process1()
            fallthrough
            
        case 2:
            process1()
            fallthrough
            
        case 1:
            process1()
            fallthrough
            
        case 0:
            return avalanche(h2)
            
            
        default:
            break
        }
        
        return 0    // unreachable, but some compilers complain without it
    }
    
}



// MARK: - Digest(One-shot)
extension XXH64 {
    
    static private func digest(_ array: [UInt8], seed: UInt64, endian: xxHash.Common.Endian) -> UInt64 {
        
        let len = array.count
        var h: UInt64
        var index = 0
        
        if len >= 32 {
            let limit = len - 32
            var v1: UInt64 = seed &+ prime1 &+ prime2
            var v2: UInt64 = seed &+ prime2
            var v3: UInt64 = seed + 0
            var v4: UInt64 = seed &- prime1
            
            repeat {
                
                v1 = round(v1, input: xxHash.Common.UInt8ArrayToUInt(array, index: index))
                index += 8
                
                v2 = round(v2, input: xxHash.Common.UInt8ArrayToUInt(array, index: index))
                index += 8
                
                v3 = round(v3, input: xxHash.Common.UInt8ArrayToUInt(array, index: index))
                index += 8
                
                v4 = round(v4, input: xxHash.Common.UInt8ArrayToUInt(array, index: index))
                index += 8
                
            } while(index <= limit)
            
            h = xxHash.Common.rotl(v1, r: 1)  &+
                xxHash.Common.rotl(v2, r: 7)  &+
                xxHash.Common.rotl(v3, r: 12) &+
                xxHash.Common.rotl(v4, r: 18)
            
            h = mergeRound(h, val: v1)
            h = mergeRound(h, val: v2)
            h = mergeRound(h, val: v3)
            h = mergeRound(h, val: v4)
        } else {
            h = seed &+ prime5
        }
        
        h &+= UInt64(len)
        
        let array2 = Array(array[index...])
        h = finalize(h, array: array2, len: len, endian: endian)
        
        return h
    }
    
    
    /// Generate digest(One-shot)
    ///
    /// - Parameters:
    ///   - array: A source data for hash.
    ///   - seed: A seed for generate digest. Default is 0.
    /// - Returns: A generated digest.
    static public func digest(_ array: [UInt8], seed: UInt64 = 0) -> UInt64 {
        return digest(array, seed: seed, endian: xxHash.Common.endian())
    }
    
    /// Overload func for "digest(_ array: [UInt8], seed: UInt64 = 0)".
    static public func digest(_ string: String, seed: UInt64 = 0) -> UInt64 {
        return digest(Array(string.utf8), seed: seed, endian: xxHash.Common.endian())
    }
    
    /// Overload func for "digest(_ array: [UInt8], seed: UInt64 = 0)".
    static public func digest(_ data: Data, seed: UInt64 = 0) -> UInt64 {
        return digest([UInt8](data), seed: seed, endian: xxHash.Common.endian())
    }
    
    
    /// Generate digest's hex string(One-shot)
    ///
    /// - Parameters:
    ///   - array: A source data for hash.
    ///   - seed: A seed for generate digest. Default is 0.
    /// - Returns: A generated digest's hex string.
    static public func digestHex(_ array: [UInt8], seed: UInt64 = 0) -> String {
        let h = digest(array, seed: seed)
        return xxHash.Common.UInt64ToHex(h)
    }
    
    /// Overload func for "digestHex(_ array: [UInt8], seed: UInt64 = 0)".
    static public func digestHex(_ string: String, seed: UInt64 = 0) -> String {
        let h = digest(string, seed: seed)
        return xxHash.Common.UInt64ToHex(h)
    }
    
    /// Overload func for "digestHex(_ array: [UInt8], seed: UInt64 = 0)".
    static public func digestHex(_ data: Data, seed: UInt64 = 0) -> String {
        let h = digest(data, seed: seed)
        return xxHash.Common.UInt64ToHex(h)
    }
}



// MARK: - Digest(Streaming)
extension XXH64 {
    
    /// Reset current streaming state to initial.
    public func reset() {
        state = xxHash.Common.State()
        
        state.v1 = seed &+ XXH64.prime1 &+ XXH64.prime2
        state.v2 = seed &+ XXH64.prime2
        state.v3 = seed + 0
        state.v4 = seed &- XXH64.prime1
    }
    
    
    /// Update streaming state.
    ///
    /// - Parameter array: A source data for hash.
    public func update(_ array: [UInt8]) {
        let len = array.count
        var index = 0
        
        state.totalLen += UInt64(len)
        
        if state.memSize + len < 32 {
            
            // fill in tmp buffer
            state.mem.replaceSubrange(state.memSize..<state.memSize + len, with: array)
            state.memSize += len
            
            return
        }
        
        
        if state.memSize > 0 {
            // some data left from previous update
            state.mem.replaceSubrange(state.memSize..<state.memSize + (32 - state.memSize),
                                      with: array)
            
            state.v1 = XXH64.round(state.v1, input: xxHash.Common.UInt8ArrayToUInt(state.mem, index: 0, endian: endian))
            state.v2 = XXH64.round(state.v2, input: xxHash.Common.UInt8ArrayToUInt(state.mem, index: 8, endian: endian))
            state.v3 = XXH64.round(state.v3, input: xxHash.Common.UInt8ArrayToUInt(state.mem, index: 16, endian: endian))
            state.v4 = XXH64.round(state.v4, input: xxHash.Common.UInt8ArrayToUInt(state.mem, index: 24, endian: endian))
            
            index += 32 - state.memSize
            state.memSize = 0
        }
        
        if index + 32 <= len {
            
            let limit = len - 32
            
            repeat {
                
                state.v1 = XXH64.round(state.v1, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
                index += 8
                
                state.v2 = XXH64.round(state.v2, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
                index += 8
                
                state.v3 = XXH64.round(state.v3, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
                index += 8
                
                state.v4 = XXH64.round(state.v4, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
                index += 8
                
            } while (index <= limit)
            
        }
        
        
        if index < len {
            state.mem.replaceSubrange(0..<len - index,
                                      with: array[index..<index + (len - index)])
            
            state.memSize = len - index
        }
        
    }
    
    /// Overload func for "update(_ array: [UInt8])".
    public func update(_ string: String) {
        return update(Array(string.utf8))
    }
    
    /// Overload func for "update(_ array: [UInt8])".
    public func update(_ data: Data) {
        return update([UInt8](data))
    }
    
    
    /// Generate digest(Streaming)
    ///
    /// - Returns: A generated digest from current streaming state.
    public func digest() -> UInt64 {
        var h: UInt64
        
        if state.totalLen >= 32 {
            h = xxHash.Common.rotl(state.v1, r: 1)  &+
                xxHash.Common.rotl(state.v2, r: 7)  &+
                xxHash.Common.rotl(state.v3, r: 12) &+
                xxHash.Common.rotl(state.v4, r: 18)
            
            h = XXH64.mergeRound(h, val: state.v1)
            h = XXH64.mergeRound(h, val: state.v2)
            h = XXH64.mergeRound(h, val: state.v3)
            h = XXH64.mergeRound(h, val: state.v4)
            
        } else {
            h = state.v3 /* == seed */ &+ XXH64.prime5
        }
        
        h &+= state.totalLen
        
        h = XXH64.finalize(h, array: state.mem, len: state.memSize, endian: endian)
        
        return h
    }
    
    
    /// Generate digest's hex string(Streaming)
    ///
    /// - Returns: A generated digest's hex string from current streaming state.
    public func digestHex() -> String {
        let h = digest()
        return xxHash.Common.UInt64ToHex(h)
    }
    
}



// MARK: - Canonical
extension XXH64 {
    
    static private func canonicalFromHash(_ hash: UInt64, endian: xxHash.Common.Endian) -> [UInt8] {
        var hash2 = hash
        if endian == xxHash.Common.Endian.little {
            hash2 = xxHash.Common.swap(hash2)
        }
        
        return xxHash.Common.UIntToUInt8Array(hash2, endian: endian)
    }
    
    /// Get canonical from hash value.
    ///
    /// - Parameter hash: A target hash value.
    /// - Returns: An array of canonical.
    static public func canonicalFromHash(_ hash: UInt64) -> [UInt8] {
        return canonicalFromHash(hash, endian: xxHash.Common.endian())
    }
    
    
    static private func hashFromCanonical(_ canonical: [UInt8], endian: xxHash.Common.Endian) -> UInt64 {
        var hash: UInt64 = xxHash.Common.UInt8ArrayToUInt(canonical, index: 0, endian: endian)
        if endian == xxHash.Common.Endian.little {
            hash = xxHash.Common.swap(hash)
        }
        
        return hash
    }
    
    /// Get hash value from canonical.
    ///
    /// - Parameter canonical: A target canonical.
    /// - Returns: A hash value.
    static public func hashFromCanonical(_ canonical: [UInt8]) -> UInt64 {
        return hashFromCanonical(canonical, endian: xxHash.Common.endian())
    }
    
}

public typealias xxHash32 = XXH32
public class XXH32 {
    
    // MARK: - Enum, Const
    static let prime1: UInt32 = 2654435761    // 0b10011110001101110111100110110001
    static let prime2: UInt32 = 2246822519    // 0b10000101111010111100101001110111
    static let prime3: UInt32 = 3266489917    // 0b11000010101100101010111000111101
    static let prime4: UInt32 =  668265263    // 0b00100111110101001110101100101111
    static let prime5: UInt32 =  374761393    // 0b00010110010101100110011110110001
    
    
    
    // MARK: - Property
    private let endian = xxHash.Common.endian()
    private var state = xxHash.Common.State<UInt32>()
    
    /// A seed for generate digest. Default is 0.
    public var seed: UInt32 {
        didSet {
            reset()
        }
    }
    
    
    
    // MARK: - Life cycle
    
    /// Creates a new instance with the seed.
    ///
    /// - Parameter seed: A seed for generate digest. Default is 0.
    public init(_ seed: UInt32 = 0) {
        self.seed = seed
        reset()
    }
    
}



// MARK: - Utility
extension XXH32 {
    
    static private func round(_ seed: UInt32, input: UInt32) -> UInt32 {
        var seed2 = seed
        seed2 &+= input &* prime2
        seed2 = xxHash.Common.rotl(seed2, r: 13)
        seed2 &*= prime1
        
        return seed2
    }
    
    static private func avalanche(_ h: UInt32) -> UInt32 {
        var h2 = h
        h2 ^= h2 >> 15
        h2 &*= prime2
        h2 ^= h2 >> 13
        h2 &*= prime3
        h2 ^= h2 >> 16
        
        return h2
    }
    
}



// MARK: - Finalize
extension XXH32 {
    
    static private func finalize(_ h: UInt32, array: [UInt8], len: Int, endian: xxHash.Common.Endian) -> UInt32 {
        var index = 0
        var h2 = h
        
        func process1() {
            h2 &+= UInt32(array[index]) &* prime5
            index += 1
            h2 = xxHash.Common.rotl(h2, r: 11) &* prime1
        }
        
        func process4() {
            h2 &+= xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian) &* prime3
            index += 4
            h2 = xxHash.Common.rotl(h2, r: 17) &* prime4
        }
        
        
        switch len & 15 {
        case 12:
            process4()
            fallthrough
            
        case 8:
            process4()
            fallthrough
            
        case 4:
            process4()
            return avalanche(h2)
            
            
        case 13:
            process4()
            fallthrough
            
        case 9:
            process4()
            fallthrough
            
        case 5:
            process4()
            process1()
            return avalanche(h2)
            
            
        case 14:
            process4()
            fallthrough
            
        case 10:
            process4()
            fallthrough
            
        case 6:
            process4()
            process1()
            process1()
            return avalanche(h2)
            
            
        case 15:
            process4()
            fallthrough
            
        case 11:
            process4()
            fallthrough
            
        case 7:
            process4()
            fallthrough
            
        case 3:
            process1()
            fallthrough
            
        case 2:
            process1()
            fallthrough
            
        case 1:
            process1()
            fallthrough
            
        case 0:
            return avalanche(h2)
            
        default:
            break
        }
        
        return h2    // reaching this point is deemed impossible
    }
    
}



// MARK: - Digest(One-shot)
extension XXH32 {
    
    static private func digest(_ array: [UInt8], seed: UInt32, endian: xxHash.Common.Endian) -> UInt32 {
        let len = array.count
        var h: UInt32
        var index = 0
        
        if len >= 16 {
            let limit = len - 15
            var v1: UInt32 = seed &+ prime1 &+ prime2
            var v2: UInt32 = seed &+ prime2
            var v3: UInt32 = seed + 0
            var v4: UInt32 = seed &- prime1
            
            repeat {
                
                v1 = round(v1, input: xxHash.Common.UInt8ArrayToUInt(array, index: index))
                index += 4
                
                v2 = round(v2, input: xxHash.Common.UInt8ArrayToUInt(array, index: index))
                index += 4
                
                v3 = round(v3, input: xxHash.Common.UInt8ArrayToUInt(array, index: index))
                index += 4
                
                v4 = round(v4, input: xxHash.Common.UInt8ArrayToUInt(array, index: index))
                index += 4
                
            } while(index < limit)
            
            h = xxHash.Common.rotl(v1, r: 1)  &+
                xxHash.Common.rotl(v2, r: 7)  &+
                xxHash.Common.rotl(v3, r: 12) &+
                xxHash.Common.rotl(v4, r: 18)
        } else {
            h = seed &+ prime5
        }
        
        h &+= UInt32(len)
        
        let array2 = Array(array[index...])
        h = finalize(h, array: array2, len: len & 15, endian: endian)
        
        return h
    }
    
    
    /// Generate digest(One-shot)
    ///
    /// - Parameters:
    ///   - array: A source data for hash.
    ///   - seed: A seed for generate digest. Default is 0.
    /// - Returns: A generated digest.
    static public func digest(_ array: [UInt8], seed: UInt32 = 0) -> UInt32 {
        return digest(array, seed: seed, endian: xxHash.Common.endian())
    }
    
    /// Overload func for "digest(_ array: [UInt8], seed: UInt32 = 0)".
    static public func digest(_ string: String, seed: UInt32 = 0) -> UInt32 {
        return digest(Array(string.utf8), seed: seed, endian: xxHash.Common.endian())
    }
    
    /// Overload func for "digest(_ array: [UInt8], seed: UInt32 = 0)".
    static public func digest(_ data: Data, seed: UInt32 = 0) -> UInt32 {
        return digest([UInt8](data), seed: seed, endian: xxHash.Common.endian())
    }
    
    
    /// Generate digest's hex string(One-shot)
    ///
    /// - Parameters:
    ///   - array: A source data for hash.
    ///   - seed: A seed for generate digest. Default is 0.
    /// - Returns: A generated digest's hex string.
    static public func digestHex(_ array: [UInt8], seed: UInt32 = 0) -> String {
        let h = digest(array, seed: seed)
        return xxHash.Common.UInt32ToHex(h)
    }
    
    /// Overload func for "digestHex(_ array: [UInt8], seed: UInt32 = 0)".
    static public func digestHex(_ string: String, seed: UInt32 = 0) -> String {
        let h = digest(string, seed: seed)
        return xxHash.Common.UInt32ToHex(h)
    }
    
    /// Overload func for "digestHex(_ array: [UInt8], seed: UInt32 = 0)".
    static public func digestHex(_ data: Data, seed: UInt32 = 0) -> String {
        let h = digest(data, seed: seed)
        return xxHash.Common.UInt32ToHex(h)
    }
}



// MARK: - Digest(Streaming)
extension XXH32 {
    
    /// Reset current streaming state to initial.
    public func reset() {
        state = xxHash.Common.State()
        
        state.v1 = seed &+ XXH32.prime1 &+ XXH32.prime2
        state.v2 = seed &+ XXH32.prime2
        state.v3 = seed + 0
        state.v4 = seed &- XXH32.prime1
    }
    
    
    /// Update streaming state.
    ///
    /// - Parameter array: A source data for hash.
    public func update(_ array: [UInt8]) {
        let len = array.count
        var index = 0
        
        state.totalLen += UInt32(len)
        state.largeLen = (len >= 16) || (state.totalLen >= 16)
        
        if state.memSize + len < 16 {
            
            // fill in tmp buffer
            state.mem.replaceSubrange(state.memSize..<state.memSize + len, with: array)
            state.memSize += len
            
            return
        }
        
        
        if state.memSize > 0 {
            // some data left from previous update
            state.mem.replaceSubrange(state.memSize..<state.memSize + (16 - state.memSize),
                                      with: array)
            
            state.v1 = XXH32.round(state.v1, input: xxHash.Common.UInt8ArrayToUInt(state.mem, index: 0, endian: endian))
            state.v2 = XXH32.round(state.v2, input: xxHash.Common.UInt8ArrayToUInt(state.mem, index: 4, endian: endian))
            state.v3 = XXH32.round(state.v3, input: xxHash.Common.UInt8ArrayToUInt(state.mem, index: 8, endian: endian))
            state.v4 = XXH32.round(state.v4, input: xxHash.Common.UInt8ArrayToUInt(state.mem, index: 12, endian: endian))
            
            index += 16 - state.memSize
            state.memSize = 0
        }
        
        if index <= len - 16 {
            
            let limit = len - 16
            
            repeat {
                
                state.v1 = XXH32.round(state.v1, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
                index += 4
                
                state.v2 = XXH32.round(state.v2, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
                index += 4
                
                state.v3 = XXH32.round(state.v3, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
                index += 4
                
                state.v4 = XXH32.round(state.v4, input: xxHash.Common.UInt8ArrayToUInt(array, index: index, endian: endian))
                index += 4
                
            } while (index <= limit)
            
        }
        
        
        if index < len {
            state.mem.replaceSubrange(0..<len - index,
                                      with: array[index..<index + (len - index)])
            
            state.memSize = len - index
        }
        
    }
    
    /// Overload func for "update(_ array: [UInt8])".
    public func update(_ string: String) {
        return update(Array(string.utf8))
    }
    
    /// Overload func for "update(_ array: [UInt8])".
    public func update(_ data: Data) {
        return update([UInt8](data))
    }
    
    
    /// Generate digest(Streaming)
    ///
    /// - Returns: A generated digest from current streaming state.
    public func digest() -> UInt32 {
        var h: UInt32
        
        if state.largeLen {
            h = xxHash.Common.rotl(state.v1, r: 1)  &+
                xxHash.Common.rotl(state.v2, r: 7)  &+
                xxHash.Common.rotl(state.v3, r: 12) &+
                xxHash.Common.rotl(state.v4, r: 18)
            
        } else {
            h = state.v3 /* == seed */ &+ XXH32.prime5
        }
        
        h &+= state.totalLen
        
        h = XXH32.finalize(h, array: state.mem, len: state.memSize, endian: endian)
        
        return h
    }
    
    
    /// Generate digest's hex string(Streaming)
    ///
    /// - Returns: A generated digest's hex string from current streaming state.
    public func digestHex() -> String {
        let h = digest()
        return xxHash.Common.UInt32ToHex(h)
    }
    
}



// MARK: - Canonical
extension XXH32 {
    
    static private func canonicalFromHash(_ hash: UInt32, endian: xxHash.Common.Endian) -> [UInt8] {
        var hash2 = hash
        if endian == xxHash.Common.Endian.little {
            hash2 = xxHash.Common.swap(hash2)
        }
        
        return xxHash.Common.UIntToUInt8Array(hash2, endian: endian)
    }
    
    /// Get canonical from hash value.
    ///
    /// - Parameter hash: A target hash value.
    /// - Returns: An array of canonical.
    static public func canonicalFromHash(_ hash: UInt32) -> [UInt8] {
        return canonicalFromHash(hash, endian: xxHash.Common.endian())
    }
    
    
    static private func hashFromCanonical(_ canonical: [UInt8], endian: xxHash.Common.Endian) -> UInt32 {
        var hash: UInt32 = xxHash.Common.UInt8ArrayToUInt(canonical, index: 0, endian: endian)
        if endian == xxHash.Common.Endian.little {
            hash = xxHash.Common.swap(hash)
        }
        
        return hash
    }
    
    /// Get hash value from canonical.
    ///
    /// - Parameter canonical: A target canonical.
    /// - Returns: A hash value.
    static public func hashFromCanonical(_ canonical: [UInt8]) -> UInt32 {
        return hashFromCanonical(canonical, endian: xxHash.Common.endian())
    }
    
}
