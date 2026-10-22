import Foundation

/// App Translocation(격리된 다운로드를 읽기 전용 임시 경로에서 실행) 처리.
enum AppTranslocation {
    // 원래 번들 경로를 돌려준다.
    static func originalBundleURL() -> URL {
        let url = Bundle.main.bundleURL
        typealias IsTranslocated =
            @convention(c) (CFURL, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<Unmanaged<CFError>?>?) ->
            DarwinBoolean
        typealias CreateOriginal =
            @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        guard let handle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
            let isSym = dlsym(handle, "SecTranslocateIsTranslocatedURL"),
            let createSym = dlsym(handle, "SecTranslocateCreateOriginalPathForURL")
        else { return url }
        var translocated = false
        guard unsafeBitCast(isSym, to: IsTranslocated.self)(url as CFURL, &translocated, nil).boolValue, translocated,
            let original = unsafeBitCast(createSym, to: CreateOriginal.self)(url as CFURL, nil)
        else { return url }
        return original.takeRetainedValue() as URL
    }
}
