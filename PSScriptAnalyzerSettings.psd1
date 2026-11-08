@{
    Severity     = @('Error', 'Warning')
    # 交互式诊断脚本需要彩色输出；模板以演示为主，不强制 ShouldProcess（写操作由 Wco.Common 的 -Apply 控制）
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingPositionalParameters',
        'PSUseDeclaredVarsMoreThanAssignments'
    )
}
