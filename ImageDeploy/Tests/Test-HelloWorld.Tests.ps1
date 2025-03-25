Describe 'HelloWorld Functionality' {
    It 'should return Hello, World!' {
        $result = HelloWorld
        $result | Should -Be 'Hello, World!'
    }
}