function Set-DownloadProgressPreference {

    if($Config.downloadProgress){
        $Global:ProgressPreference = "Continue"
    }
    else{
        $Global:ProgressPreference = "SilentlyContinue"
    }

}
