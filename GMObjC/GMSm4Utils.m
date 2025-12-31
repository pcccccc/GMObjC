#import "GMSm4Utils.h"
#import "GMSmUtils.h"
#import <openssl/evp.h>

// SM4 block size is 16 bytes
#define GM_SM4_BLOCK_SIZE 16

@implementation GMSm4Utils

// OpenSSL 1.1.1 以上版本支持国密
+ (void)initialize {
    if (self == [GMSm4Utils class]) {
        if (OPENSSL_VERSION_NUMBER < 0x1010100fL) {
            NSAssert1(NO, @"OpenSSL 版本低于 1.1.1，不支持国密，OpenSSL 当前版本：%s", OPENSSL_VERSION_TEXT);
        }
    }
}

// MARK: - 生成 SM4 密钥
/// 生成 SM4 密钥（HEX 编码格式）。返回值：长度为 GM_SM4_BLOCK_SIZE(16) 字节密钥
+ (nullable NSString *)generateKey {
    NSInteger len = GM_SM4_BLOCK_SIZE;
    uint8_t bytes[len];
    int status = SecRandomCopyBytes(kSecRandomDefault, (sizeof bytes)/(sizeof bytes[0]), &bytes);
    if (status == errSecSuccess) {
        NSData *resultData = [NSData dataWithBytes:bytes length:len];
        return [GMSmUtils hexStringFromData:resultData];
    }
    // 容错，若 SecRandomCopyBytes 失败
    NSString *keyStr = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    NSMutableString *randomStr = [[NSMutableString alloc] initWithCapacity:len];
    for (int i = 0; i < len; i++){
        uint32_t index = arc4random_uniform((uint32_t)keyStr.length);
        NSString *subChar = [keyStr substringWithRange:NSMakeRange(index, 1)];
        [randomStr appendString:subChar];
    }
    NSData *randomData = [randomStr dataUsingEncoding:NSUTF8StringEncoding];
    return [GMSmUtils hexStringFromData:randomData];
}

// MARK: - ECB 加密
/// SM4 ECB 模式加密。返回值：加密后的密文（HEX 编码格式）
/// @param plaintext 明文（字符串类型）
/// @param keyHex  密钥（HEX 编码格式）
+ (nullable NSString *)encryptTextWithECB:(NSString *)plaintext keyHex:(NSString *)keyHex {
    if (plaintext.length == 0 || keyHex.length == 0) {
        return nil;
    }
    NSData *plainData = [plaintext dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData = [GMSmUtils dataFromHexString:keyHex];
    NSData *cipherData = [self encryptDataWithECB:plainData keyData:keyData];
    NSString *cipherHex = [GMSmUtils hexStringFromData:cipherData];
    return cipherHex;
}

/// SM4 ECB 模式加密。返回值：加密后的密文
/// @param plainData 明文（NSData 类型）
/// @param keyData SM4 密钥，长度  GM_SM4_BLOCK_SIZE(16) 字节任意数据
+ (nullable NSData *)encryptDataWithECB:(NSData *)plainData keyData:(NSData *)keyData {
    if (plainData.length == 0 || keyData.length != GM_SM4_BLOCK_SIZE) {
        return nil;
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (ctx == NULL) {
        return nil;
    }

    const unsigned char *key = (const unsigned char *)[keyData bytes];
    const unsigned char *input = (const unsigned char *)[plainData bytes];
    int inputLen = (int)[plainData length];

    // 分配输出缓冲区 (输入长度 + 一个块的填充)
    int maxOutputLen = inputLen + GM_SM4_BLOCK_SIZE;
    unsigned char *output = (unsigned char *)OPENSSL_zalloc(maxOutputLen);
    if (output == NULL) {
        EVP_CIPHER_CTX_free(ctx);
        return nil;
    }

    int outLen = 0;
    int finalLen = 0;
    NSData *result = nil;

    // 使用 EVP API 进行 ECB 加密 (自动 PKCS7 填充)
    if (EVP_EncryptInit_ex(ctx, EVP_sm4_ecb(), NULL, key, NULL) == 1 &&
        EVP_EncryptUpdate(ctx, output, &outLen, input, inputLen) == 1 &&
        EVP_EncryptFinal_ex(ctx, output + outLen, &finalLen) == 1) {
        result = [NSData dataWithBytes:output length:(outLen + finalLen)];
    }

    OPENSSL_free(output);
    EVP_CIPHER_CTX_free(ctx);
    return result;
}

// MARK: - ECB 解密
/// SM4 ECB 模式解密。返回值：解密后的明文（HEX 编码格式）
/// @param ciphertext 密文（HEX 编码格式）
/// @param keyHex 密钥（HEX 编码格式）
+ (nullable NSString *)decryptTextWithECB:(NSString *)ciphertext keyHex:(NSString *)keyHex {
    NSData *cipherData = [GMSmUtils dataFromHexString:ciphertext];
    NSData *keyData = [GMSmUtils dataFromHexString:keyHex];
    NSData *plainData = [self decryptDataWithECB:cipherData keyData:keyData];
    if (plainData.length > 0) {
        NSString *plaintext = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
        return plaintext;
    }
    return nil;
}

/// SM4 ECB 模式解密。返回值：解密后的明文
/// @param cipherData 密文（NSData 类型）
/// @param keyData SM4 密钥，长度  GM_SM4_BLOCK_SIZE(16) 字节任意数据
+ (nullable NSData *)decryptDataWithECB:(NSData *)cipherData keyData:(NSData *)keyData {
    if (cipherData.length == 0 || keyData.length != GM_SM4_BLOCK_SIZE) {
        return nil;
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (ctx == NULL) {
        return nil;
    }

    const unsigned char *key = (const unsigned char *)[keyData bytes];
    const unsigned char *input = (const unsigned char *)[cipherData bytes];
    int inputLen = (int)[cipherData length];

    // 分配输出缓冲区
    unsigned char *output = (unsigned char *)OPENSSL_zalloc(inputLen + GM_SM4_BLOCK_SIZE);
    if (output == NULL) {
        EVP_CIPHER_CTX_free(ctx);
        return nil;
    }

    int outLen = 0;
    int finalLen = 0;
    NSData *result = nil;

    // 使用 EVP API 进行 ECB 解密 (自动移除 PKCS7 填充)
    if (EVP_DecryptInit_ex(ctx, EVP_sm4_ecb(), NULL, key, NULL) == 1 &&
        EVP_DecryptUpdate(ctx, output, &outLen, input, inputLen) == 1 &&
        EVP_DecryptFinal_ex(ctx, output + outLen, &finalLen) == 1) {
        result = [NSData dataWithBytes:output length:(outLen + finalLen)];
    }

    OPENSSL_free(output);
    EVP_CIPHER_CTX_free(ctx);
    return result;
}

// MARK: - CBC 加密
/// SM4 CBC 模式加密。返回值：加密后的密文（HEX 编码格式）
/// @param plaintext 明文（字符串类型）
/// @param keyHex 密钥（HEX 编码格式）
/// @param ivecHex 密钥（HEX 编码格式），确保加解密相同即可
+ (nullable NSString *)encryptTextWithCBC:(NSString *)plaintext keyHex:(NSString *)keyHex ivecHex:(NSString *)ivecHex {
    if (plaintext.length == 0 || keyHex.length == 0) {
        return nil;
    }
    NSData *plainData = [plaintext dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData = [GMSmUtils dataFromHexString:keyHex];
    NSData *ivecData = [GMSmUtils dataFromHexString:ivecHex];
    NSData *cipherData = [self encryptDataWithCBC:plainData keyData:keyData ivecData:ivecData];
    NSString *cipherHex = [GMSmUtils hexStringFromData:cipherData];
    return cipherHex;
}

/// SM4 CBC 模式加密。返回值：加密后的密文
/// @param plainData 明文（NSData 类型）
/// @param keyData SM4 密钥，长度  GM_SM4_BLOCK_SIZE(16) 字节任意数据
/// @param ivecData CBC 模式需传入长度  GM_SM4_BLOCK_SIZE(16) 字节任意字符，确保加解密相同即可
+ (nullable NSData *)encryptDataWithCBC:(NSData *)plainData keyData:(NSData *)keyData ivecData:(NSData *)ivecData {
    if (plainData.length == 0 || keyData.length != GM_SM4_BLOCK_SIZE || ivecData.length != GM_SM4_BLOCK_SIZE) {
        return nil;
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (ctx == NULL) {
        return nil;
    }

    const unsigned char *key = (const unsigned char *)[keyData bytes];
    const unsigned char *iv = (const unsigned char *)[ivecData bytes];
    const unsigned char *input = (const unsigned char *)[plainData bytes];
    int inputLen = (int)[plainData length];

    // 分配输出缓冲区 (输入长度 + 一个块的填充)
    int maxOutputLen = inputLen + GM_SM4_BLOCK_SIZE;
    unsigned char *output = (unsigned char *)OPENSSL_zalloc(maxOutputLen);
    if (output == NULL) {
        EVP_CIPHER_CTX_free(ctx);
        return nil;
    }

    int outLen = 0;
    int finalLen = 0;
    NSData *result = nil;

    // 使用 EVP API 进行 CBC 加密 (自动 PKCS7 填充)
    if (EVP_EncryptInit_ex(ctx, EVP_sm4_cbc(), NULL, key, iv) == 1 &&
        EVP_EncryptUpdate(ctx, output, &outLen, input, inputLen) == 1 &&
        EVP_EncryptFinal_ex(ctx, output + outLen, &finalLen) == 1) {
        result = [NSData dataWithBytes:output length:(outLen + finalLen)];
    }

    OPENSSL_free(output);
    EVP_CIPHER_CTX_free(ctx);
    return result;
}

// MARK: - CBC 解密
/// SM4 CBC 模式解密。返回值：解密后的明文
/// @param ciphertext 密文（字符串类型）
/// @param keyHex 密钥（HEX 编码格式）
/// @param ivecHex 密钥（HEX 编码格式），确保加解密相同即可
+ (nullable NSString *)decryptTextWithCBC:(NSString *)ciphertext keyHex:(NSString *)keyHex ivecHex:(NSString *)ivecHex {
    NSData *cipherData = [GMSmUtils dataFromHexString:ciphertext];
    NSData *keyData = [GMSmUtils dataFromHexString:keyHex];
    NSData *ivecData = [GMSmUtils dataFromHexString:ivecHex];
    NSData *plainData = [self decryptDataWithCBC:cipherData keyData:keyData ivecData:ivecData];
    if (plainData.length > 0) {
        NSString *plaintext = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
        return plaintext;
    }
    return nil;
}

/// SM4 CBC 模式解密。返回值：解密后的明文
/// @param cipherData 密文（NSData 类型）
/// @param keyData SM4 密钥，长度 GM_SM4_BLOCK_SIZE(16) 字节任意数据
/// @param ivecData CBC 模式需传入长度  GM_SM4_BLOCK_SIZE(16) 字节任意字符，确保加解密相同即可
+ (nullable NSData *)decryptDataWithCBC:(NSData *)cipherData keyData:(NSData *)keyData ivecData:(NSData *)ivecData {
    if (cipherData.length == 0 || keyData.length != GM_SM4_BLOCK_SIZE || ivecData.length != GM_SM4_BLOCK_SIZE) {
        return nil;
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (ctx == NULL) {
        return nil;
    }

    const unsigned char *key = (const unsigned char *)[keyData bytes];
    const unsigned char *iv = (const unsigned char *)[ivecData bytes];
    const unsigned char *input = (const unsigned char *)[cipherData bytes];
    int inputLen = (int)[cipherData length];

    // 分配输出缓冲区
    unsigned char *output = (unsigned char *)OPENSSL_zalloc(inputLen + GM_SM4_BLOCK_SIZE);
    if (output == NULL) {
        EVP_CIPHER_CTX_free(ctx);
        return nil;
    }

    int outLen = 0;
    int finalLen = 0;
    NSData *result = nil;

    // 使用 EVP API 进行 CBC 解密 (自动移除 PKCS7 填充)
    if (EVP_DecryptInit_ex(ctx, EVP_sm4_cbc(), NULL, key, iv) == 1 &&
        EVP_DecryptUpdate(ctx, output, &outLen, input, inputLen) == 1 &&
        EVP_DecryptFinal_ex(ctx, output + outLen, &finalLen) == 1) {
        result = [NSData dataWithBytes:output length:(outLen + finalLen)];
    }

    OPENSSL_free(output);
    EVP_CIPHER_CTX_free(ctx);
    return result;
}

@end
