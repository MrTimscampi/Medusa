<%inherit file="/layouts/main.mako"/>
<%!
    import re
    from medusa import app
    from medusa.common import SKIPPED, WANTED, UNAIRED, ARCHIVED, IGNORED, SNATCHED, SNATCHED_PROPER, SNATCHED_BEST, FAILED
    from medusa.common import Quality, qualityPresets, statusStrings, qualityPresetStrings, cpu_presets, MULTI_EP_STRINGS
    from medusa.indexers.indexer_api import indexerApi
    from medusa.indexers.utils import get_trakt_indexer
%>
<%block name="scripts">
<script>
window.app = {};
window.app = new Vue({
    store,
    router,
    el: '#vue-wrap',
    data() {
        return {
            configLoaded: false,
            prowlSelectedShow: null,
            prowlSelectedShowApiKeys: null,
            prowlPriorityOptions: [
                { text: 'Very Low', value: -2 },
                { text: 'Moderate', value: -1 },
                { text: 'Normal', value: 0 },
                { text: 'High', value: 1 },
                { text: 'Emergency', value: 2 }
            ],
            pushoverSoundOptions: [
                { text: 'Pushover', value: 'pushover' },
                { text: 'Bike', value: 'bike' },
                { text: 'Bugle', value: 'bugle' },
                { text: 'Cash Register', value: 'cashregister' },
                { text: 'classical', value: 'classical' },
                { text: 'Cosmic', value: 'cosmic' },
                { text: 'Falling', value: 'falling' },
                { text: 'Gamelan', value: 'gamelan' },
                { text: 'Incoming', value: 'incoming' },
                { text: 'Intermission', value: 'intermission' },
                { text: 'Magic', value: 'magic' },
                { text: 'Mechanical', value: 'mechanical' },
                { text: 'Piano Bar', value: 'pianobar' },
                { text: 'Siren', value: 'siren' },
                { text: 'Space Alarm', value: 'spacealarm' },
                { text: 'Tug Boat', value: 'tugboat' },
                { text: 'Alien Alarm (long)', value: 'alien' },
                { text: 'Climb (long)', value: 'climb' },
                { text: 'Persistent (long)', value: 'persistant' },
                { text: 'Pushover Echo (long)', value: 'echo' },
                { text: 'Up Down (long)', value: 'updown' },
                { text: 'None (silent)', value: 'none' },
                { text: 'Device specific', value: 'default' }
            ],
            pushbulletDeviceOptions: [
                { text: 'All devices', value: '' }
            ],
            pushbulletTestInfo: 'Click below to test.',
            notifiers: {
                emby: {
                    enabled: null,
                    host: null,
                    apiKey: null
                },
                kodi: {
                    enabled: null,
                    alwaysOn: null,
                    libraryCleanPending: null,
                    cleanLibrary: null,
                    host: [],
                    username: null,
                    password: null,
                    notify: {
                        snatch: null,
                        download: null,
                        subtitleDownload: null
                    },
                    update: {
                        library: null,
                        full: null,
                        onlyFirst: null
                    }
                },
                plex: {
                    client: {
                        host: [],
                        username: null,
                        enabled: null,
                        notifyOnSnatch: null,
                        notifyOnDownload: null,
                        notifyOnSubtitleDownload: null
                    },
                    server: {
                        updateLibrary: null,
                        host: [],
                        enabled: null,
                        https: null,
                        username: null,
                        password: null,
                        token: null,
                        notify: {
                            download: null,
                            subtitleDownload: null,
                            snatch: null
                        }
                    }
                },
                nmj: {
                    enabled: null,
                    host: null,
                    database: null,
                    mount: null
                },
                nmjv2: {
                    enabled: null,
                    host: null,
                    dbloc: null,
                    database: null
                },
                synologyIndex: {
                    enabled: null
                },
                synology: {
                    enabled: null,
                    notifyOnSnatch: null,
                    notifyOnDownload: null,
                    notifyOnSubtitleDownload: null
                },
                pyTivo: {
                    enabled: null,
                    host: null,
                    name: null,
                    shareName: null
                },
                growl: {
                    enabled: null,
                    host: null,
                    password: null,
                    notifyOnSnatch: null,
                    notifyOnDownload: null,
                    notifyOnSubtitleDownload: null
                },
                prowl: {
                    enabled: null,
                    api: [],
                    messageTitle: null,
                    piority: null,
                    notifyOnSnatch: null,
                    notifyOnDownload: null,
                    notifyOnSubtitleDownload: null
                },
                libnotify: {
                    enabled: null,
                    notifyOnSnatch: null,
                    notifyOnDownload: null,
                    notifyOnSubtitleDownload: null
                },
                pushover: {
                    enabled: null,
                    apiKey: null,
                    userKey: null,
                    device: [],
                    sound: null,
                    notifyOnSnatch: null,
                    notifyOnDownload: null,
                    notifyOnSubtitleDownload: null
                },
                boxcar2: {
                    enabled: null,
                    notifyOnSnatch: null,
                    notifyOnDownload: null,
                    notifyOnSubtitleDownload: null,
                    accessToken: null
                },
                pushalot: {
                    enabled: null,
                    notifyOnSnatch: null,
                    notifyOnDownload: null,
                    notifyOnSubtitleDownload: null,
                    authToken: null
                },
                pushbullet: {
                    enabled: null,
                    notifyOnSnatch: null,
                    notifyOnDownload: null,
                    notifyOnSubtitleDownload: null,
                    authToken: null,
                    device: ''
                }
            }
        };
    },
    computed: {
        stateNotifiers() {
            return this.$store.state.notifiers;
        }
    },
    created() {
        const { $store } = this;
        // Needed for the show-selector component
        $store.dispatch('getShows');
    },
    mounted() {
        $('#testGrowl').on('click', function() {
            const growl = {};
            growl.host = $.trim($('#growl_host').find('input').val());
            growl.password = $.trim($('#growl_password').find('input').val());
            if (!growl.host) {
                $('#testGrowl-result').html('Please fill out the necessary fields above.');
                $('#growl_host').find('input').addClass('warning');
                return;
            }
            $('#growl_host').find('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testGrowl-result').html(MEDUSA.config.loading);
            $.get('home/testGrowl', {
                host: growl.host,
                password: growl.password
            }).done(data => {
                $('#testGrowl-result').html(data);
                $('#testGrowl').prop('disabled', false);
            });
        });

        $('#testProwl').on('click', function() {
            const prowl = {};
            prowl.api = $.trim($('#prowl_api').find('input').val());
            prowl.priority = $('#prowl_priority').find('input').val();
            if (!prowl.api) {
                $('#testProwl-result').html('Please fill out the necessary fields above.');
                $('#prowl_api').find('input').addClass('warning');
                return;
            }
            $('#prowl_api').find('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testProwl-result').html(MEDUSA.config.loading);
            $.get('home/testProwl', {
                prowl_api: prowl.api, // eslint-disable-line camelcase
                prowl_priority: prowl.priority // eslint-disable-line camelcase
            }).done(data => {
                $('#testProwl-result').html(data);
                $('#testProwl').prop('disabled', false);
            });
        });

        $('#testKODI').on('click', function() {
            const kodi = {};
            kodi.host = $.trim($('#kodi_host').find('input').val());
            kodi.username = $.trim($('#kodi_username').find('input').val());
            kodi.password = $.trim($('#kodi_password').find('input').val());
            if (!kodi.host) {
                $('#testKODI-result').html('Please fill out the necessary fields above.');
                $('#kodi_host').addClass('warning');
                return;
            }
            $('#kodi_host').find('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testKODI-result').html(MEDUSA.config.loading);
            $.get('home/testKODI', {
                host: kodi.host,
                username: kodi.username,
                password: kodi.password
            }).done(data => {
                $('#testKODI-result').html(data);
                $('#testKODI').prop('disabled', false);
            });
        });

        $('#testPHT').on('click', function() {
            const plex = {};
            plex.client = {};
            plex.client.host = $.trim($('#plex_client_host').find('input').val());
            plex.client.username = $.trim($('#plex_client_username').find('input').val());
            plex.client.password = $.trim($('#plex_client_password').find('input').val());
            if (!plex.client.host) {
                $('#testPHT-result').html('Please fill out the necessary fields above.');
                $('#plex_client_host').find('input').addClass('warning');
                return;
            }
            $('#plex_client_host').find('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testPHT-result').html(MEDUSA.config.loading);
            $.get('home/testPHT', {
                host: plex.client.host,
                username: plex.client.username,
                password: plex.client.password
            }).done(data => {
                $('#testPHT-result').html(data);
                $('#testPHT').prop('disabled', false);
            });
        });

        $('#testPMS').on('click', function() {
            const plex = {};
            plex.server = {};
            plex.server.host = $.trim($('#plex_server_host').find('input').val());
            plex.server.username = $.trim($('#plex_server_username').find('input').val());
            plex.server.password = $.trim($('#plex_server_password').find('input').val());
            plex.server.token = $.trim($('#plex_server_token').find('input').val());
            if (!plex.server.host) {
                $('#testPMS-result').html('Please fill out the necessary fields above.');
                $('#plex_server_host').find('input').addClass('warning');
                return;
            }
            $('#plex_server_host').find('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testPMS-result').html(MEDUSA.config.loading);
            $.get('home/testPMS', {
                host: plex.server.host,
                username: plex.server.username,
                password: plex.server.password,
                plex_server_token: plex.server.token // eslint-disable-line camelcase
            }).done(data => {
                $('#testPMS-result').html(data);
                $('#testPMS').prop('disabled', false);
            });
        });

        $('#testEMBY').on('click', function() {
            const emby = {};
            emby.host = $('#emby_host').find('input').val();
            emby.apikey = $('#emby_apikey').find('input').val();
            if (!emby.host || !emby.apikey) {
                $('#testEMBY-result').html('Please fill out the necessary fields above.');
                $('#emby_host').find('input').addRemoveWarningClass(emby.host);
                $('#emby_apikey').find('input').addRemoveWarningClass(emby.apikey);
                return;
            }
            $('#emby_host,#emby_apikey').children('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testEMBY-result').html(MEDUSA.config.loading);
            $.get('home/testEMBY', {
                host: emby.host,
                emby_apikey: emby.apikey // eslint-disable-line camelcase
            }).done(data => {
                $('#testEMBY-result').html(data);
                $('#testEMBY').prop('disabled', false);
            });
        });

        $('#testBoxcar2').on('click', function() {
            const boxcar2 = {};
            boxcar2.accesstoken = $.trim($('#boxcar2_accesstoken').find('input').val());
            if (!boxcar2.accesstoken) {
                $('#testBoxcar2-result').html('Please fill out the necessary fields above.');
                $('#boxcar2_accesstoken').find('input').addClass('warning');
                return;
            }
            $('#boxcar2_accesstoken').find('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testBoxcar2-result').html(MEDUSA.config.loading);
            $.get('home/testBoxcar2', {
                accesstoken: boxcar2.accesstoken
            }).done(data => {
                $('#testBoxcar2-result').html(data);
                $('#testBoxcar2').prop('disabled', false);
            });
        });

        $('#testPushover').on('click', function() {
            const pushover = {};
            pushover.userkey = $('#pushover_userkey').find('input').val();
            pushover.apikey = $('#pushover_apikey').find('input').val();
            if (!pushover.userkey || !pushover.apikey) {
                $('#testPushover-result').html('Please fill out the necessary fields above.');
                $('#pushover_userkey').find('input').addRemoveWarningClass(pushover.userkey);
                $('#pushover_apikey').find('input').addRemoveWarningClass(pushover.apikey);
                return;
            }
            $('#pushover_userkey,#pushover_apikey').children('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testPushover-result').html(MEDUSA.config.loading);
            $.get('home/testPushover', {
                userKey: pushover.userkey,
                apiKey: pushover.apikey
            }).done(data => {
                $('#testPushover-result').html(data);
                $('#testPushover').prop('disabled', false);
            });
        });

        $('#testLibnotify').on('click', () => {
            $('#testLibnotify-result').html(MEDUSA.config.loading);
            $.get('home/testLibnotify', data => {
                $('#testLibnotify-result').html(data);
            });
        });

        $('#twitterStep1').on('click', () => {
            $('#testTwitter-result').html(MEDUSA.config.loading);
            $.get('home/twitterStep1', data => {
                window.open(data);
            }).done(() => {
                $('#testTwitter-result').html('<b>Step1:</b> Confirm Authorization');
            });
        });

        $('#twitterStep2').on('click', () => {
            const twitter = {};
            twitter.key = $.trim($('#twitter_key').val());
            $('#twitter_key').addRemoveWarningClass(twitter.key);
            if (twitter.key) {
                $('#testTwitter-result').html(MEDUSA.config.loading);
                $.get('home/twitterStep2', {
                    key: twitter.key
                }, data => {
                    $('#testTwitter-result').html(data);
                });
            }
            $('#testTwitter-result').html('Please fill out the necessary fields above.');
        });

        $('#testTwitter').on('click', () => {
            $.get('home/testTwitter', data => {
                $('#testTwitter-result').html(data);
            });
        });

        $('#settingsNMJ').on('click', () => {
            const nmj = {};
            if ($('#nmj_host').find('input').val()) {
                $('#testNMJ-result').html(MEDUSA.config.loading);
                nmj.host = $('#nmj_host').find('input').val();

                $.get('home/settingsNMJ', {
                    host: nmj.host
                }, data => {
                    if (data === null) {
                        $('#nmj_database').removeAttr('readonly');
                        $('#nmj_mount').removeAttr('readonly');
                    }
                    const JSONData = $.parseJSON(data);
                    $('#testNMJ-result').html(JSONData.message);
                    $('#nmj_database').val(JSONData.database);
                    $('#nmj_mount').val(JSONData.mount);

                    if (JSONData.database) {
                        $('#nmj_database').prop('readonly', true);
                    } else {
                        $('#nmj_database').removeAttr('readonly');
                    }
                    if (JSONData.mount) {
                        $('#nmj_mount').prop('readonly', true);
                    } else {
                        $('#nmj_mount').removeAttr('readonly');
                    }
                });
            }
            alert('Please fill in the Popcorn IP address'); // eslint-disable-line no-alert
            $('#nmj_host').focus();
        });

        $('#testNMJ').on('click', function() {
            const nmj = {};
            nmj.host = $.trim($('#nmj_host').val());
            nmj.database = $('#nmj_database').val();
            nmj.mount = $('#nmj_mount').val();
            if (nmj.host) {
                $('#nmj_host').removeClass('warning');
                $(this).prop('disabled', true);
                $('#testNMJ-result').html(MEDUSA.config.loading);
                $.get('home/testNMJ', {
                    host: nmj.host,
                    database: nmj.database,
                    mount: nmj.mount
                }).done(data => {
                    $('#testNMJ-result').html(data);
                    $('#testNMJ').prop('disabled', false);
                });
            }
            $('#testNMJ-result').html('Please fill out the necessary fields above.');
            $('#nmj_host').addClass('warning');
        });

        $('#settingsNMJv2').on('click', () => {
            const nmjv2 = {};
            if ($('#nmjv2_host').val()) {
                $('#testNMJv2-result').html(MEDUSA.config.loading);
                nmjv2.host = $('#nmjv2_host').val();
                nmjv2.dbloc = '';
                const radios = document.getElementsByName('nmjv2_dbloc');
                for (let i = 0, len = radios.length; i < len; i++) {
                    if (radios[i].checked) {
                        nmjv2.dbloc = radios[i].value;
                        break;
                    }
                }

                nmjv2.dbinstance = $('#NMJv2db_instance').val();
                $.get('home/settingsNMJv2', {
                    host: nmjv2.host,
                    dbloc: nmjv2.dbloc,
                    instance: nmjv2.dbinstance
                }, data => {
                    if (data === null) {
                        $('#nmjv2_database').removeAttr('readonly');
                    }
                    const JSONData = $.parseJSON(data);
                    $('#testNMJv2-result').html(JSONData.message);
                    $('#nmjv2_database').val(JSONData.database);

                    if (JSONData.database) {
                        $('#nmjv2_database').prop('readonly', true);
                    } else {
                        $('#nmjv2_database').removeAttr('readonly');
                    }
                });
            }
            alert('Please fill in the Popcorn IP address'); // eslint-disable-line no-alert
            $('#nmjv2_host').focus();
        });

        $('#testNMJv2').on('click', function() {
            const nmjv2 = {};
            nmjv2.host = $.trim($('#nmjv2_host').val());
            if (nmjv2.host) {
                $('#nmjv2_host').removeClass('warning');
                $(this).prop('disabled', true);
                $('#testNMJv2-result').html(MEDUSA.config.loading);
                $.get('home/testNMJv2', {
                    host: nmjv2.host
                }).done(data => {
                    $('#testNMJv2-result').html(data);
                    $('#testNMJv2').prop('disabled', false);
                });
            }
            $('#testNMJv2-result').html('Please fill out the necessary fields above.');
            $('#nmjv2_host').addClass('warning');
        });

        $('#testFreeMobile').on('click', function() {
            const freemobile = {};
            freemobile.id = $.trim($('#freemobile_id').val());
            freemobile.apikey = $.trim($('#freemobile_apikey').val());
            if (!freemobile.id || !freemobile.apikey) {
                $('#testFreeMobile-result').html('Please fill out the necessary fields above.');
                if (freemobile.id) {
                    $('#freemobile_id').removeClass('warning');
                } else {
                    $('#freemobile_id').addClass('warning');
                }
                if (freemobile.apikey) {
                    $('#freemobile_apikey').removeClass('warning');
                } else {
                    $('#freemobile_apikey').addClass('warning');
                }
                return;
            }
            $('#freemobile_id,#freemobile_apikey').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testFreeMobile-result').html(MEDUSA.config.loading);
            $.get('home/testFreeMobile', {
                freemobile_id: freemobile.id, // eslint-disable-line camelcase
                freemobile_apikey: freemobile.apikey // eslint-disable-line camelcase
            }).done(data => {
                $('#testFreeMobile-result').html(data);
                $('#testFreeMobile').prop('disabled', false);
            });
        });

        $('#testTelegram').on('click', function() {
            const telegram = {};
            telegram.id = $.trim($('#telegram_id').val());
            telegram.apikey = $.trim($('#telegram_apikey').val());
            if (!telegram.id || !telegram.apikey) {
                $('#testTelegram-result').html('Please fill out the necessary fields above.');
                $('#telegram_id').addRemoveWarningClass(telegram.id);
                $('#telegram_apikey').addRemoveWarningClass(telegram.apikey);
                return;
            }
            $('#telegram_id,#telegram_apikey').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testTelegram-result').html(MEDUSA.config.loading);
            $.get('home/testTelegram', {
                telegram_id: telegram.id, // eslint-disable-line camelcase
                telegram_apikey: telegram.apikey // eslint-disable-line camelcase
            }).done(data => {
                $('#testTelegram-result').html(data);
                $('#testTelegram').prop('disabled', false);
            });
        });

        $('#testSlack').on('click', function() {
            const slack = {};
            slack.webhook = $.trim($('#slack_webhook').val());

            if (!slack.webhook) {
                $('#testSlack-result').html('Please fill out the necessary fields above.');
                $('#slack_webhook').addRemoveWarningClass(slack.webhook);
                return;
            }
            $('#slack_webhook').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testSlack-result').html(MEDUSA.config.loading);
            $.get('home/testslack', {
                slack_webhook: slack.webhook // eslint-disable-line camelcase
            }).done(data => {
                $('#testSlack-result').html(data);
                $('#testSlack').prop('disabled', false);
            });
        });

        $('#TraktGetPin').on('click', () => {
            window.open($('#trakt_pin_url').val(), 'popUp', 'toolbar=no, scrollbars=no, resizable=no, top=200, left=200, width=650, height=550');
            $('#trakt_pin').prop('disabled', false);
        });

        $('#trakt_pin').on('keyup change', () => {
            if ($('#trakt_pin').val().length === 0) {
                $('#TraktGetPin').removeClass('hide');
                $('#authTrakt').addClass('hide');
            } else {
                $('#TraktGetPin').addClass('hide');
                $('#authTrakt').removeClass('hide');
            }
        });

        $('#authTrakt').on('click', () => {
            const trakt = {};
            trakt.pin = $('#trakt_pin').val();
            if (trakt.pin.length !== 0) {
                $.get('home/getTraktToken', {
                    trakt_pin: trakt.pin // eslint-disable-line camelcase
                }).done(data => {
                    $('#testTrakt-result').html(data);
                    $('#authTrakt').addClass('hide');
                    $('#trakt_pin').prop('disabled', true);
                    $('#trakt_pin').val('');
                    $('#TraktGetPin').removeClass('hide');
                });
            }
        });

        $('#testTrakt').on('click', function() {
            const trakt = {};
            trakt.username = $.trim($('#trakt_username').val());
            trakt.trendingBlacklist = $.trim($('#trakt_blacklist_name').val());
            if (!trakt.username) {
                $('#testTrakt-result').html('Please fill out the necessary fields above.');
                $('#trakt_username').addRemoveWarningClass(trakt.username);
                return;
            }

            if (/\s/g.test(trakt.trendingBlacklist)) {
                $('#testTrakt-result').html('Check blacklist name; the value needs to be a trakt slug');
                $('#trakt_blacklist_name').addClass('warning');
                return;
            }
            $('#trakt_username').removeClass('warning');
            $('#trakt_blacklist_name').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testTrakt-result').html(MEDUSA.config.loading);
            $.get('home/testTrakt', {
                username: trakt.username,
                blacklist_name: trakt.trendingBlacklist // eslint-disable-line camelcase
            }).done(data => {
                $('#testTrakt-result').html(data);
                $('#testTrakt').prop('disabled', false);
            });
        });

        $('#forceSync').on('click', () => {
            $('#testTrakt-result').html(MEDUSA.config.loading);
            $.getJSON('home/forceTraktSync', data => {
                $('#testTrakt-result').html(data.result);
            });
        });

        $('#testEmail').on('click', () => {
            let to = '';
            const status = $('#testEmail-result');
            status.html(MEDUSA.config.loading);
            let host = $('#email_host').val();
            host = host.length > 0 ? host : null;
            let port = $('#email_port').val();
            port = port.length > 0 ? port : null;
            const tls = $('#email_tls').is(':checked') ? 1 : 0;
            let from = $('#email_from').val();
            from = from.length > 0 ? from : 'root@localhost';
            const user = $('#email_user').val().trim();
            const pwd = $('#email_password').val();
            let err = '';
            if (host === null) {
                err += '<li style="color: red;">You must specify an SMTP hostname!</li>';
            }
            if (port === null) {
                err += '<li style="color: red;">You must specify an SMTP port!</li>';
            } else if (port.match(/^\d+$/) === null || parseInt(port, 10) > 65535) {
                err += '<li style="color: red;">SMTP port must be between 0 and 65535!</li>';
            }
            if (err.length > 0) {
                err = '<ol>' + err + '</ol>';
                status.html(err);
            } else {
                to = prompt('Enter an email address to send the test to:', null); // eslint-disable-line no-alert
                if (to === null || to.length === 0 || to.match(/.*@.*/) === null) {
                    status.html('<p style="color: red;">You must provide a recipient email address!</p>');
                } else {
                    $.get('home/testEmail', {
                        host,
                        port,
                        smtp_from: from, // eslint-disable-line camelcase
                        use_tls: tls, // eslint-disable-line camelcase
                        user,
                        pwd,
                        to
                    }, msg => {
                        $('#testEmail-result').html(msg);
                    });
                }
            }
        });

        $('#testPushalot').on('click', function() {
            const pushalot = {};
            pushalot.authToken = $.trim($('#pushalot_authorizationtoken').val());
            if (!pushalot.authToken) {
                $('#testPushalot-result').html('Please fill out the necessary fields above.');
                $('#pushalot_authorizationtoken').addClass('warning');
                return;
            }
            $('#pushalot_authorizationtoken').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testPushalot-result').html(MEDUSA.config.loading);
            $.get('home/testPushalot', {
                authorizationToken: pushalot.authToken
            }).done(data => {
                $('#testPushalot-result').html(data);
                $('#testPushalot').prop('disabled', false);
            });
        });

        $('#testPushbullet').on('click', function() {
            const pushbullet = {};
            pushbullet.api = $.trim($('#pushbullet_api').find('input').val());
            if (!pushbullet.api) {
                $('#testPushbullet-result').html('Please fill out the necessary fields above.');
                $('#pushbullet_api').find('input').addClass('warning');
                return;
            }
            $('#pushbullet_api').find('input').removeClass('warning');
            $(this).prop('disabled', true);
            $('#testPushbullet-result').html(MEDUSA.config.loading);
            $.get('home/testPushbullet', {
                api: pushbullet.api
            }).done(data => {
                $('#testPushbullet-result').html(data);
                $('#testPushbullet').prop('disabled', false);
            });
        });

        $('#email_show').on('change', () => {
            const key = parseInt($('#email_show').val(), 10);
            $.getJSON('home/loadShowNotifyLists', notifyData => {
                if (notifyData._size > 0) {
                    $('#email_show_list').val(key >= 0 ? notifyData[key.toString()].list : '');
                }
            });
        });
        $('#prowl_show').on('change', () => {
            const key = parseInt($('#prowl_show').val(), 10);
            $.getJSON('home/loadShowNotifyLists', notifyData => {
                if (notifyData._size > 0) {
                    $('#prowl_show_list').val(key >= 0 ? notifyData[key.toString()].prowl_notify_list : '');
                }
            });
        });

        function loadShowNotifyLists() {
            $.getJSON('home/loadShowNotifyLists', list => {
                let html;
                let s;
                if (list._size === 0) {
                    return;
                }

                // Convert the 'list' object to a js array of objects so that we can sort it
                const _list = [];
                for (s in list) {
                    if (s.charAt(0) !== '_') {
                        _list.push(list[s]);
                    }
                }
                const sortedList = _list.sort((a, b) => {
                    if (a.name < b.name) {
                        return -1;
                    }
                    if (a.name > b.name) {
                        return 1;
                    }
                    return 0;
                });
                html = '<option value="-1">-- Select --</option>';
                for (s in sortedList) {
                    if (sortedList[s].id && sortedList[s].name) {
                        html += '<option value="' + sortedList[s].id + '">' + $('<div/>').text(sortedList[s].name).html() + '</option>';
                    }
                }
                $('#email_show').html(html);
                $('#email_show_list').val('');

                $('#prowl_show').html(html);
                $('#prowl_show_list').val('');
            });
        }
        // Load the per show notify lists everytime this page is loaded
        loadShowNotifyLists();

        // Update the internal data struct anytime settings are saved to the server
        $('#email_show').on('notify', loadShowNotifyLists);
        $('#prowl_show').on('notify', loadShowNotifyLists);

        $('#email_show_save').on('click', () => {
            $.post('home/saveShowNotifyList', {
                show: $('#email_show').val(),
                emails: $('#email_show_list').val()
            }, loadShowNotifyLists);
        });
        $('#prowl_show_save').on('click', () => {
            $.post('home/saveShowNotifyList', {
                show: $('#prowl_show').val(),
                prowlAPIs: $('#prowl_show_list').val()
            }, () => {
                // Reload the per show notify lists to reflect changes
                loadShowNotifyLists();
            });
        });

        // Show instructions for plex when enabled
        $('#use_plex_server').on('click', function() {
            if ($(this).is(':checked')) {
                $('.plexinfo').removeClass('hide');
            } else {
                $('.plexinfo').addClass('hide');
            }
        });

        // The real vue stuff
        // This is used to wait for the config to be loaded by the store.
        this.$once('loaded', () => {
            const { config, stateNotifiers } = this;

            // Map the state values to local data.
            this.notifiers = Object.assign({}, this.notifiers, stateNotifiers);
            this.configLoaded = true;
        });

    },
    methods: {
        onChangeProwlApi(items) {
            this.notifiers.prowl.api = items.map(item => item.value);
        },
        saveProwlPerShowNotifyList(item) {
            const { prowlSelectedShow, prowlSelectedShowApiKeys, prowlUpdateApiKeys } = this;
            
            let form = new FormData();
            form.set('show', prowlSelectedShow)
            form.set('prowlAPIs', prowlSelectedShowApiKeys)

            apiRoute.post('home/saveShowNotifyList', form).then(() => {
                // Reload the per show notify lists to reflect changes
                prowlUpdateApiKeys(prowlSelectedShow);
            });
        },
        async prowlUpdateApiKeys(selectedShow) {
            this.prowlSelectedShow = selectedShow; 
            const response = await apiRoute('home/loadShowNotifyLists')
            if (response.data._size > 0) {
                this.prowlSelectedShowApiKeys = selectedShow ? response.data[selectedShow].prowl_notify_list : '';
            }
        },
        async getPushbulletDeviceOptions() {
            const { api: pushbulletApiKey } = this.notifiers.pushbullet;
            if (!pushbulletApiKey) {
                this.pushbulletTestInfo = 'You didn\'t supply a Pushbullet api key';
                $('#pushbullet_api').find('input').focus();
                return false;
            }

            const response = await apiRoute('home/getPushbulletDevices', { params: { api: pushbulletApiKey }});
            let options = [];

            const { data } = response;
            if (!data) {
                return false;
            }

            options.push({text: 'All devices', value: ''});
            for (device of data.devices) {
                if (device.active === true) {
                    options.push({text: device.nickname, value: device.iden});
                }
            }
            this.pushbulletDeviceOptions = options;
            this.pushbulletTestInfo = 'Device list updated. Please choose a device to push to.';
        },
        async testPushbulletApi() {
            const { api: pushbulletApiKey } = this.notifiers.pushbullet;
            if (!pushbulletApiKey) {
                this.pushbulletTestInfo = 'You didn\'t supply a Pushbullet api key';
                $('#pushbullet_api').find('input').focus();
                return false;
            }

            const response = await apiRoute('home/testPushbullet', { params: { api: pushbulletApiKey }});
            const { data } = response;
            
            if (data) {
                this.pushbulletTestInfo = data;
            }
        }
    }
});
</script>
</%block>
<%block name="content">
<h1 class="header">{{ $route.meta.header }}</h1>
<div id="config">
    <div id="config-content">
        <form id="configForm" action="config/notifications/saveNotifications" method="post">
            <div id="config-components">
                <ul>
                    <li><app-link href="#home-theater-nas">Home Theater / NAS</app-link></li>
                    <li><app-link href="#devices">Devices</app-link></li>
                    <li><app-link href="#social">Social</app-link></li>
                </ul>
                
                <div id="home-theater-nas">    
                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-kodi" title="KODI"></span>
                            <h3><app-link href="http://kodi.tv">KODI</app-link></h3>
                            <p>A free and open source cross-platform media center and home entertainment system software with a 10-foot user interface designed for the living-room TV.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for KODI -->

                                <config-toggle-slider :checked="notifiers.kodi.enabled" label="Enable" id="use_kodi" :explanations="['Send KODI commands?']" @change="save()"  @update="notifiers.kodi.enabled = $event"></config-toggle-slider>

                                <div v-show="notifiers.kodi.enabled" id="content-use-kodi"> <!-- show based on notifiers.kodi.enabled -->

                                    <config-toggle-slider :checked="notifiers.kodi.alwaysOn" label="Always on" id="kodi_always_on" :explanations="['log errors when unreachable?']" @change="save()"  @update="notifiers.kodi.alwaysOn = $event"></config-toggle-slider>
                                    
                                    <config-toggle-slider :checked="notifiers.kodi.notify.snatch" label="Notify on snatch" id="kodi_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.kodi.notify.snatch = $event"></config-toggle-slider>

                                    <config-toggle-slider :checked="notifiers.kodi.notify.download" label="Notify on download" id="kodi_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.kodi.notify.download = $event"></config-toggle-slider>
                                    
                                    <config-toggle-slider :checked="notifiers.kodi.notify.subtitleDownload" label="Notify on subtitle download" id="kodi_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.kodi.notify.subtitleDownload = $event"></config-toggle-slider>
                                        
                                    <config-toggle-slider :checked="notifiers.kodi.notify.library" label="Update library" id="kodi_update_library" :explanations="['update KODI library when a download finishes?']" @change="save()"  @update="notifiers.kodi.notify.library = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.kodi.update.full" label="Full library update" id="kodi_update_full" :explanations="['perform a full library update if update per-show fails?']" @change="save()"  @update="notifiers.kodi.update.full = $event"></config-toggle-slider>

                                    <config-toggle-slider :checked="notifiers.kodi.cleanLibrary" label="Clean library" id="kodi_clean_library" :explanations="['clean KODI library when replaces a already downloaded episode?']" @change="save()"  @update="notifiers.kodi.cleanLibrary = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.kodi.update.onlyFirst" label="Only update first host" id="kodi_update_onlyfirst" :explanations="['only send library updates/clean to the first active host?']" @change="save()"  @update="notifiers.kodi.update.onlyFirst = $event"></config-toggle-slider>
                                    
                                    
                                    <div class="form-group">
                                        <div class="row">
                                            <label for="kodi_host" class="col-sm-2 control-label">
                                                <span>KODI IP:Port</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <select-list name="kodi_host" id="kodi_host" :list-items="notifiers.kodi.host" @change="notifiers.kodi.host = $event"></select-list>
                                                <p>host running KODI (eg. 192.168.1.100:8080)</p>
                                            </div>
                                        </div>
                                    </div>

                                    <config-textbox :value="notifiers.kodi.username" label="Username" id="kodi_username" :explanations="['username for your KODI server (blank for none)']" @change="save()"  @update="notifiers.kodi.username = $event"></config-textbox>
                                    <config-textbox :value="notifiers.kodi.password" type="password" label="Password" id="kodi_password" :explanations="['password for your KODI server (blank for none)']" @change="save()" @update="notifiers.kodi.password = $event"></config-textbox>

                                    <div class="testNotification" id="testKODI-result">Click below to test.</div>
                                    <input  class="btn-medusa" type="button" value="Test KODI" id="testKODI" />
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                            
                                </div>

                            </fieldset>    
                        </div>

                    </div>

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-plex" title="Plex Media Server"></span>
                            <h3><app-link href="https://plex.tv">Plex Media Server</app-link></h3>
                            <p>Experience your media on a visually stunning, easy to use interface on your Mac connected to your TV. Your media library has never looked this good!</p>
                            <p class="plexinfo hide">For sending notifications to Plex Home Theater (PHT) clients, use the KODI notifier with port <b>3005</b>.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for plex media server -->
                                <div class="form-group">
                                    <div class="row">
                                        <label for="use_plex_server" class="col-sm-2 control-label">
                                            <span>Enable</span>
                                        </label>
                                        <div class="col-sm-10 content">
                                            <toggle-button :width="45" :height="22" id="use_kodi" name="use_kodi" v-model="notifiers.plex.server.enabled" sync></toggle-button>
                                            <p>Send Plex Media Server library updates?</p>
                                        </div>
                                    </div>
                                </div>

                                <div v-show="notifiers.plex.server.enabled" id="content-use-plex-server"> <!-- show based on notifiers.plex.server.enabled -->
                                    <div class="form-group">
                                        <div class="row">
                                            <label for="plex_server_token" class="col-sm-2 control-label">
                                                <span>Plex Media Server Auth Token</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <input type="text" name="plex_server_token" id="plex_server_token" v-model="notifiers.plex.server.token" @change="save()" @update="notifiers.plex.server.token = $event"/>
                                                <!-- Can't use the config-textbox component, because of the complex descriptions -->
                                                <p>Auth Token used by plex</p>
                                                <p><span>See: <app-link href="https://support.plex.tv/hc/en-us/articles/204059436-Finding-your-account-token-X-Plex-Token" class="wiki"><strong>Finding your account token</strong></app-link></span></p>
                                            </div>
                                        </div>
                                    </div>

                                    <config-textbox :value="notifiers.plex.server.username" label="Username" id="plex_server_username" :explanations="['blank = no authentication']" @change="save()"  @update="notifiers.plex.server.username = $event"></config-textbox>
                                    <config-textbox :value="notifiers.plex.server.password" type="password" label="Password" id="plex_server_password" :explanations="['blank = no authentication']" @change="save()"  @update="notifiers.plex.server.password = $event"></config-textbox>
                                    
                                    <config-toggle-slider :checked="notifiers.plex.server.updateLibrary" label="Update Library" id="plex_update_library" :explanations="['log errors when unreachable?']" @change="save()"  @update="notifiers.plex.server.updateLibrary = $event"></config-toggle-slider>
                                    <div class="form-group">
                                        <div class="row">
                                            <label for="kodi_host" class="col-sm-2 control-label">
                                                <span>Plex Media Server IP:Port</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <select-list name="plex_server_host" id="plex_server_host" :list-items="notifiers.plex.server.host" @change="notifiers.plex.server.host = $event"></select-list>
                                                <p>one or more hosts running Plex Media Server<br>(eg. 192.168.1.1:32400, 192.168.1.2:32400)</p>
                                            </div>
                                        </div>
                                    </div>
    
                                    <config-toggle-slider :checked="notifiers.plex.server.https" label="HTTPS" id="plex_server_https" :explanations="['use https for plex media server requests?']" @change="save()"  @update="notifiers.plex.server.https = $event"></config-toggle-slider>
                                    
                                    <div class="field-pair">
                                        <div class="testNotification" id="testPMS-result">Click below to test Plex Media Server(s)</div>
                                        <input class="btn-medusa" type="button" value="Test Plex Media Server" id="testPMS" />
                                        <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                        <div class="clear-left">&nbsp;</div>
                                    </div>
                            
                                </div>
                            </fieldset>
                        </div>
                    </div>    

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-plexth" title="Plex Media Client"></span>
                            <h3><app-link href="https://plex.tv">Plex Home Theater</app-link></h3>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for plex media client -->
                                <config-toggle-slider :checked="notifiers.plex.client.enabled" label="Enable" id="use_plex_client" :explanations="['Send Plex Home Theater notifications?']" @change="save()"  @update="notifiers.plex.client.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.plex.client.enabled" id="content-use-plex-client"> <!-- show based on notifiers.plex.server.enabled -->
                                    <config-toggle-slider :checked="notifiers.plex.client.notifyOnSnatch" label="Notify on snatch" id="plex_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.plex.client.notifyOnSnatch = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.plex.client.notifyOnDownload" label="Notify on download" id="plex_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.plex.client.notifyOnDownload = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.plex.client.notifyOnSubtitleDownload" label="Notify on subtitle download" id="plex_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.plex.client.notifyOnSubtitleDownload = $event"></config-toggle-slider>

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="kodi_host" class="col-sm-2 control-label">
                                                <span>Plex Home Theater IP:Port</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <select-list name="plex_client_host" id="plex_client_host" :list-items="notifiers.plex.client.host" @change="notifiers.plex.client.host = $event"></select-list>
                                                <p>one or more hosts running Plex Home Theater<br>(eg. 192.168.1.100:3000, 192.168.1.101:3000)</p>
                                            </div>
                                        </div>
                                    </div>
    
                                    <config-textbox :value="notifiers.plex.client.username" label="Username" id="plex_client_username" :explanations="['blank = no authentication']" @change="save()"  @update="notifiers.plex.server.username = $event"></config-textbox>
                                    <config-textbox :value="notifiers.plex.client.password" type="password" label="Password" id="plex_client_password" :explanations="['blank = no authentication']" @change="save()"  @update="notifiers.plex.server.password = $event"></config-textbox>

                                    <div class="field-pair">
                                        <div class="testNotification" id="testPHT-result">Click below to test Plex Home Theater(s)</div>
                                        <input class="btn-medusa" type="button" value="Test Plex Home Theater" id="testPHT" />
                                        <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                        <div class=clear-left><p>Note: some Plex Home Theaters <b class="boldest">do not</b> support notifications e.g. Plexapp for Samsung TVs</p></div>
                                    </div>

                                </div>
                            </fieldset>
                        </div>
                    </div>

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-emby" title="Emby"></span>
                            <h3><app-link href="http://emby.media">Emby</app-link></h3>
                            <p>A home media server built using other popular open source technologies.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for emby -->
                                <config-toggle-slider :checked="notifiers.emby.enabled" label="Enable" id="use_emby" :explanations="['Send update commands to Emby?']" @change="save()"  @update="notifiers.emby.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.emby.enabled" id="content_use_emby">
                                    <config-textbox :value="notifiers.emby.host" label="Emby IP:Port" id="emby_host" :explanations="['host running Emby (eg. 192.168.1.100:8096)']" @change="save()"  @update="notifiers.emby.host = $event"></config-textbox>
                                    <config-toggle-slider :checked="notifiers.emby.apiKey" label="HTTPS" id="plex_server_https" @change="save()"  @update="notifiers.emby.apiKey = $event"></config-toggle-slider>
                                
                                    <div class="testNotification" id="testEMBY-result">Click below to test.</div>
                                    <input class="btn-medusa" type="button" value="Test Emby" id="testEMBY" />
                                </div>
                            </fieldset>
                        </div>
                    </div>

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-nmj" title="Networked Media Jukebox"></span>
                            <h3><app-link href="http://www.popcornhour.com/">NMJ</app-link></h3>
                            <p>The Networked Media Jukebox, or NMJ, is the official media jukebox interface made available for the Popcorn Hour 200-series.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for nmj -->
                                <config-toggle-slider :checked="notifiers.nmj.enabled" label="Enable" id="use_nmj" :explanations="['Send update commands to NMJ?']" @change="save()"  @update="notifiers.nmj.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.nmj.enabled" id="content-use-nmj">
                                    <config-textbox :value="notifiers.nmj.host" label="Popcorn IP address" id="nmj_host" :explanations="['IP address of Popcorn 200-series (eg. 192.168.1.100)']" @change="save()"  @update="notifiers.nmj.host = $event"></config-textbox>

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="get_nmj_settings" class="col-sm-2 control-label">
                                                <span>Get settings</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <input class="btn-medusa btn-inline" type="button" value="Get Settings" id="settingsNMJ" />            
                                                <span>the Popcorn Hour device must be powered on and NMJ running.</span>                    
                                            </div>
                                        </div>
                                    </div>

                                    <config-textbox :value="notifiers.nmj.database" label="NMJ database" id="nmj_database" :explanations="['automatically filled via the \'Get Settings\' button.']" @change="save()"  @update="notifiers.nmj.database = $event"></config-textbox>

                                    <config-textbox :value="notifiers.nmj.mount" label="NMJ mount" id="nmj_mount" :explanations="['automatically filled via the \'Get Settings\' button.']" @change="save()"  @update="notifiers.nmj.mount = $event"></config-textbox>
                                
                                    <div class="testNotification" id="testNMJ-result">Click below to test.</div>
                                    <input class="btn-medusa" type="button" value="Test NMJ" id="testNMJ" />
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />        

                                </div>
                            </fieldset>
                        </div>
                    </div>

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-nmj" title="Networked Media Jukebox v2"></span>
                            <h3><app-link href="http://www.popcornhour.com/">NMJv2</app-link></h3>
                            <p>The Networked Media Jukebox, or NMJv2, is the official media jukebox interface made available for the Popcorn Hour 300 & 400-series.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for njm (popcorn) client -->
                                <config-toggle-slider :checked="notifiers.nmjv2.enabled" label="Enable" id="use_nmjv2" :explanations="['Send popcorn hour (nmjv2) notifications?']" @change="save()"  @update="notifiers.nmjv2.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.nmjv2.enabled" id="content-use-nmjv2">

                                    <config-textbox :value="notifiers.nmjv2.host" label="Popcorn IP address" id="nmjv2_host" :explanations="['IP address of Popcorn 300/400-series (eg. 192.168.1.100)']" @change="save()"  @update="notifiers.nmjv2.host = $event"></config-textbox>

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="nmjv2_database_location" class="col-sm-2 control-label">
                                                <span>Database location</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <label for="NMJV2_DBLOC_A" class="space-right">
                                                    <input type="radio" NAME="nmjv2_dbloc" VALUE="local" id="NMJV2_DBLOC_A" v-model="notifiers.nmjv2.dbloc" value="local"/>
                                                    PCH Local Media
                                                </label>
                                                <label for="NMJV2_DBLOC_B">
                                                    <input type="radio" NAME="nmjv2_dbloc" VALUE="network" id="NMJV2_DBLOC_B" v-model="notifiers.nmjv2.dbloc" value="network"/>
                                                    PCH Network Media
                                                </label>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="nmjv2_database_instance" class="col-sm-2 control-label">
                                                <span>Database instance</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <select id="NMJv2db_instance" class="form-control input-sm">
                                                    <option value="0">#1 </option>
                                                    <option value="1">#2 </option>
                                                    <option value="2">#3 </option>
                                                    <option value="3">#4 </option>
                                                    <option value="4">#5 </option>
                                                    <option value="5">#6 </option>
                                                    <option value="6">#7 </option>
                                                </select>
                                                <span>adjust this value if the wrong database is selected.</span>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="get_nmjv2_find_database" class="col-sm-2 control-label">
                                                <span>Find database</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <input type="button" class="btn-medusa btn-inline" value="Find Database" id="settingsNMJv2" />
                                                <span>the Popcorn Hour device must be powered on.</span>
                                            </div>
                                        </div>
                                    </div>  

                                    <config-textbox :value="notifiers.nmjv2.database" label="NMJv2 database" id="nmjv2_database" :explanations="['automatically filled via the \'Find Database\' buttons.']" @change="save()"  @update="notifiers.nmjv2.database = $event"></config-textbox>
                                    <div class="testNotification" id="testNMJv2-result">Click below to test.</div>
                                    <input class="btn-medusa" type="button" value="Test NMJv2" id="testNMJv2" />
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-syno1" title="Synology"></span>
                            <h3><app-link href="http://synology.com/">Synology</app-link></h3>
                            <p>The Synology DiskStation NAS.</p>
                            <p>Synology Indexer is the daemon running on the Synology NAS to build its media database.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for synology indexer -->
                                <config-toggle-slider :checked="notifiers.synologyIndex.enabled" label="HTTPS" id="use_synoindex" :explanations="['Note: requires Medusa to be running on your Synology NAS.']" @change="save()"  @update="notifiers.synologyIndex.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.synologyIndex.enabled" id="content_use_synoindex">
                                        <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-syno2" title="Synology Indexer"></span>
                            <h3><app-link href="http://synology.com/">Synology Notifier</app-link></h3>
                            <p>Synology Notifier is the notification system of Synology DSM</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for synology notifier -->
                                <config-toggle-slider :checked="notifiers.synology.enabled" label="Enable" id="use_synologynotifier" 
                                    :explanations="['Send notifications to the Synology Notifier?', 'Note: requires Medusa to be running on your Synology DSM.']" 
                                    @change="save()"  @update="notifiers.synology.enabled = $event">
                                </config-toggle-slider>
                                <div v-show="notifiers.synology.enabled" id="content-use-synology-notifier">
                                    <config-toggle-slider :checked="notifiers.synology.notifyOnSnatch" label="Notify on snatch" id="_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.synology.notifyOnSnatch = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.synology.notifyOnDownload" label="Notify on download" id="synology_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.synology.notifyOnDownload = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.synology.notifyOnSubtitleDownload" label="Notify on subtitle download" id="synology_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.synology.notifyOnSubtitleDownload = $event"></config-toggle-slider>
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>

    
                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-pytivo" title="pyTivo"></span>
                            <h3><app-link href="http://pytivo.sourceforge.net/wiki/index.php/PyTivo">pyTivo</app-link></h3>
                            <p>pyTivo is both an HMO and GoBack server. This notifier will load the completed downloads to your Tivo.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for pyTivo client -->
                                <config-toggle-slider :checked="notifiers.pyTivo.enabled" label="Enable" id="use_pytivo" :explanations="['Send Plex Home Theater notifications?']" @change="save()"  @update="notifiers.pyTivo.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.pyTivo.enabled" id="content-use-pytivo"> <!-- show based on notifiers.pyTivo.enabled -->
                                    <config-textbox :value="notifiers.pyTivo.host" label="pyTivo IP:Port" id="pytivo_host" :explanations="['host running pyTivo (eg. 192.168.1.1:9032)']" @change="save()"  @update="notifiers.pyTivo.host = $event"></config-textbox>
                                    <config-textbox :value="notifiers.pyTivo.shareName" label="pyTivo share name" id="pytivo_name" :explanations="['(Messages \& Settings > Account \& System Information > System Information > DVR name)']" @change="save()"  @update="notifiers.pyTivo.shareName = $event"></config-textbox>
                                    <config-textbox :value="notifiers.pyTivo.name" label="Tivo name" id="pytivo_tivo_name" :explanations="['value used in pyTivo Web Configuration to name the share.']" @change="save()"  @update="notifiers.pyTivo.name = $event"></config-textbox>
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>
                </div><!-- #home-theater-nas //-->
                
                
                <div id="devices">
                    
                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-growl" title="Growl"></span>
                            <h3><app-link href="http://growl.info/">Growl</app-link></h3>
                            <p>A cross-platform unobtrusive global notification system.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for growl client -->
                                <config-toggle-slider :checked="notifiers.growl.enabled" label="Enable" id="use_growl_client" :explanations="['Send growl Home Theater notifications?']" @change="save()"  @update="notifiers.growl.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.growl.enabled" id="content-use-growl-client"> <!-- show based on notifiers.growl.enabled -->

                                    <config-toggle-slider :checked="notifiers.growl.notifyOnSnatch" label="Notify on snatch" id="growl_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.growl.notifyOnSnatch = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.growl.notifyOnDownload" label="Notify on download" id="growl_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.growl.notifyOnDownload = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.growl.notifyOnSubtitleDownload" label="Notify on subtitle download" id="growl_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.growl.notifyOnSubtitleDownload = $event"></config-toggle-slider>
                                    <config-textbox :value="notifiers.growl.host" label="Growl IP:Port" id="growl_username" :explanations="['host running Growl (eg. 192.168.1.100:23053)']" @change="save()"  @update="notifiers.growl.host = $event"></config-textbox>
                                    <config-textbox :value="notifiers.growl.password" label="Password" id="growl_password" :explanations="['may leave blank if Medusa is on the same host.', 'otherwise Growl requires a password to be used.']" @change="save()"  @update="notifiers.growl.password = $event"></config-textbox>
                                    
                                    <div class="testNotification" id="testGrowl-result">Click below to register and test Growl, this is required for Growl notifications to work.</div>
                                    <input  class="btn-medusa" type="button" value="Register Growl" id="testGrowl" />
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>
                
                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-prowl" title="Prowl"></span>
                            <h3><app-link href="http://www.prowlapp.com/">Prowl</app-link></h3>
                            <p>A Growl client for iOS.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for prowl client -->
                                <config-toggle-slider :checked="notifiers.prowl.enabled" label="Enable" id="use_prowl" :explanations="['Send Prowl notifications?']" @change="save()"  @update="notifiers.prowl.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.prowl.enabled" id="content-use-prowl"> <!-- show based on notifiers.plex.server.enabled -->
                                    <config-toggle-slider :checked="notifiers.prowl.notifyOnSnatch" label="Notify on snatch" id="prowl_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.prowl.notifyOnSnatch = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.prowl.notifyOnDownload" label="Notify on download" id="prowl_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.prowl.notifyOnDownload = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.prowl.notifyOnSubtitleDownload" label="Notify on subtitle download" id="prowl_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.prowl.notifyOnSubtitleDownload = $event"></config-toggle-slider>
                                    <config-textbox :value="notifiers.prowl.messageTitle" label="Prowl Message Title" id="prowl_message_title" @change="save()"  @update="notifiers.prowl.messageTitle = $event"></config-textbox>
                                    <div class="form-group">
                                        <div class="row">
                                            <label for="kodi_host" class="col-sm-2 control-label">
                                                <span>Api</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <select-list name="prowl_api" id="prowl_api" csv-enabled :list-items="notifiers.prowl.api" @change="onChangeProwlApi"></select-list>
                                                <span>Prowl API(s) listed here, separated by commas if applicable, will receive notifications for <b>all</b> shows.
                                                    Your Prowl API key is available at:
                                                    <app-link href="https://www.prowlapp.com/api_settings.php">
                                                    https://www.prowlapp.com/api_settings.php</app-link><br>
                                                    (This field may be blank except when testing.)
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                    

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="kodi_host" class="col-sm-2 control-label">
                                                <span>Show notification list</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <show-selector select-class="form-control input-sm max-input350" placeholder="-- Select a Show --" @change="prowlUpdateApiKeys($event)"></show-selector>
                                            </div>
                                        </div>
                                    </div>

                                    <config-textbox :value="prowlSelectedShowApiKeys" placeholder="Separate your api keys with a comma" label="" id="prowl-show-list" :explanations="['Configure per-show notifications here by entering Prowl API key(s), separated by commas, after selecting a show in the drop-down box. Be sure to activate the \'Save for this show\' button below after each entry.']" @change="saveProwlPerShowNotifyList($event)" @update="prowlSelectedShowApiKeys = $event">
                                    </config-textbox>
                                    

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="prowl-show-save-button" class="col-sm-2 control-label">
                                                <span></span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <input id="prowl-show-save-button" class="btn-medusa" type="button" value="Save for this show" @click="saveProwlPerShowNotifyList"/>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="form-group">
                                        <div class="row">
                                            <label for="kodi_host" class="col-sm-2 control-label">
                                                <span>Prowl priority:</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <select id="prowl_priority" name="prowl_priority" v-model="notifiers.prowl.priority" class="form-control input-sm">
                                                    <option v-for="option in prowlPriorityOptions" v-bind:value="option.value">
                                                            {{ option.text }}
                                                    </option>
                                                </select>
                                                <span>priority of Prowl messages from Medusa.</span>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="testNotification" id="testProwl-result">Click below to test.</div>
                                    <input  class="btn-medusa" type="button" value="Test Prowl" id="testProwl" />
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />

                                </div>
                            </fieldset>
                        </div>
                    </div>
                    
                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-libnotify" title="Libnotify"></span>
                            <h3><app-link href="http://library.gnome.org/devel/libnotify/">Libnotify</app-link></h3>
                            <p>The standard desktop notification API for Linux/*nix systems.  This notifier will only function if the pynotify module is installed (Ubuntu/Debian package <app-link href="apt:python-notify">python-notify</app-link>).</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for plex media client -->
                                <config-toggle-slider :checked="notifiers.libnotify.enabled" label="Enable" id="use_libnotify_client" :explanations="['Send Libnotify notifications?']" @change="save()"  @update="notifiers.libnotify.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.libnotify.enabled" id="content-use-libnotify"> 

                                    <config-toggle-slider :checked="notifiers.libnotify.notifyOnSnatch" label="Notify on snatch" id="libnotify_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.libnotify.notifyOnSnatch = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.libnotify.notifyOnDownload" label="Notify on download" id="libnotify_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.libnotify.notifyOnDownload = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.libnotify.notifyOnSubtitleDownload" label="Notify on subtitle download" id="libnotify_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.libnotify.notifyOnSubtitleDownload = $event"></config-toggle-slider>

                                    <div class="testNotification" id="testLibnotify-result">Click below to test.</div>
                                    <input  class="btn-medusa" type="button" value="Test Libnotify" id="testLibnotify" />
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-pushover" title="Pushover"></span>
                            <h3><app-link href="https://pushover.net/">Pushover</app-link></h3>
                            <p>Pushover makes it easy to send real-time notifications to your Android and iOS devices.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for pushover -->
                                <config-toggle-slider :checked="notifiers.pushover.enabled" label="Enable" id="use_pushover_client" :explanations="['Send Pushover notifications?']" @change="save()"  @update="notifiers.pushover.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.pushover.enabled" id="content-use-pushover">
                                    <config-toggle-slider :checked="notifiers.pushover.notifyOnSnatch" label="Notify on snatch" id="pushover_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.pushover.notifyOnSnatch = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.pushover.notifyOnDownload" label="Notify on download" id="pushover_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.pushover.notifyOnDownload = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.pushover.notifyOnSubtitleDownload" label="Notify on subtitle download" id="pushover_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.pushover.notifyOnSubtitleDownload = $event"></config-toggle-slider>

                                    <config-textbox :value="notifiers.pushover.userKey" label="Pushover Key" id="pushover_userkey" :explanations="['user key of your Pushover account']" @change="save()"  @update="notifiers.pushover.userKey = $event"></config-textbox>
                                    
                                    <div class="form-group">
                                        <div class="row">
                                            <label for="kodi_host" class="col-sm-2 control-label">
                                                    <span>Pushover API key</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <input type="text" name="pushover_apikey" id="pushover_apikey" v-model="notifiers.pushover.apiKey" class="form-control input-sm max-input350"/>
                                                <span><app-link href="https://pushover.net/apps/build/"><b>Click here</b></app-link> to create a Pushover API key</span>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="kodi_host" class="col-sm-2 control-label">
                                                <span>Pushover Devices</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <select-list name="pushover_device" id="pushover_device" :list-items="notifiers.pushover.device" @change="notifiers.pushover.device = $event"></select-list>
                                                <p>List of pushover devices you want to send notifications to</p>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="form-group">
                                        <div class="row">
                                            <label for="pushover_spound" class="col-sm-2 control-label">
                                                <span>Pushover notification sound</span>
                                            </label>
                                            <div class="col-sm-10 content">
                                                <select id="pushover_sound" name="pushover_sound" v-model="notifiers.pushover.sound" class="form-control">
                                                    <option v-for="option in pushoverSoundOptions" v-bind:value="option.value">
                                                        {{ option.text }}
                                                    </option>
                                                </select>
                                                <span>Choose notification sound to use</span>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="testNotification" id="testPushover-result">Click below to test.</div>
                                    <input  class="btn-medusa" type="button" value="Test Pushover" id="testPushover" />
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>


                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-boxcar2" title="Boxcar 2"></span>
                            <h3><app-link href="https://new.boxcar.io/">Boxcar 2</app-link></h3>
                            <p>Read your messages where and when you want them!</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for boxcar2 client -->
                                <config-toggle-slider :checked="notifiers.boxcar2.enabled" label="Enable" id="use_boxcar2" :explanations="['Send boxcar2 notifications?']" @change="save()"  @update="notifiers.boxcar2.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.boxcar2.enabled" id="content-use-boxcar2-client"> <!-- show based on notifiers.boxcar2.enabled -->

                                    <config-toggle-slider :checked="notifiers.boxcar2.notifyOnSnatch" label="Notify on snatch" id="boxcar2_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.boxcar2.notifyOnSnatch = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.boxcar2.notifyOnDownload" label="Notify on download" id="boxcar2_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.boxcar2.notifyOnDownload = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.boxcar2.notifyOnSubtitleDownload" label="Notify on subtitle download" id="boxcar2_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.boxcar2.notifyOnSubtitleDownload = $event"></config-toggle-slider>
                                    <config-textbox :value="notifiers.boxcar2.accessToken" label="Boxcar2 Access token" id="boxcar2_accesstoken" :explanations="['access token for your Boxcar account.']" @change="save()"  @update="notifiers.boxcar2.accessToken = $event"></config-textbox>
                                    
                                    <div class="testNotification" id="testBoxcar2-result">Click below to test.</div>
                                    <input  class="btn-medusa" type="button" value="Test Boxcar" id="testBoxcar2" />
                                    <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>

                    <div class="row component-group">
                        <div class="component-group-desc col-xs-12 col-md-2">
                            <span class="icon-notifiers-pushalot" title="Pushalot"></span>
                            <h3><app-link href="https://pushalot.com">Pushalot</app-link></h3>
                            <p>Pushalot is a platform for receiving custom push notifications to connected devices running Windows Phone or Windows 8.</p>
                        </div>
                        <div class="col-xs-12 col-md-10">
                            <fieldset class="component-group-list">
                                <!-- All form components here for pushalot client -->
                                <config-toggle-slider :checked="notifiers.pushalot.enabled" label="Enable" id="use_pushalot" :explanations="['Send Pushalot notifications?']" @change="save()"  @update="notifiers.pushalot.enabled = $event"></config-toggle-slider>
                                <div v-show="notifiers.pushalot.enabled" id="content-use-pushalot-client"> <!-- show based on notifiers.pushalot.enabled -->

                                    <config-toggle-slider :checked="notifiers.pushalot.notifyOnSnatch" label="Notify on snatch" id="pushalot_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.pushalot.notifyOnSnatch = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.pushalot.notifyOnDownload" label="Notify on download" id="pushalot_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.pushalot.notifyOnDownload = $event"></config-toggle-slider>
                                    <config-toggle-slider :checked="notifiers.pushalot.notifyOnSubtitleDownload" label="Notify on subtitle download" id="pushalot_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.pushalot.notifyOnSubtitleDownload = $event"></config-toggle-slider>
                                    <config-textbox :value="notifiers.pushalot.authToken" label="Pushalot authorization token" id="pushalot_authorizationtoken" :explanations="['authorization token of your Pushalot account.']" @change="save()"  @update="notifiers.pushalot.authToken = $event"></config-textbox>
                                    
                                    <div class="testNotification" id="testPushalot-result">Click below to test.</div>
                                    <input type="button" class="btn-medusa" value="Test Pushalot" id="testPushalot" />
                                    <input type="submit" class="btn-medusa config_submitter" value="Save Changes" />
                                </div>
                            </fieldset>
                        </div>
                    </div>

                    <div class="row component-group">
                            <div class="component-group-desc col-xs-12 col-md-2">
                                <span class="icon-notifiers-pushbullet" title="Pushbullet"></span>
                                <h3><app-link href="https://www.pushbullet.com">Pushbullet</app-link></h3>
                                <p>Pushbullet is a platform for receiving custom push notifications to connected devices running Android and desktop Chrome browsers.</p>
                            </div>
                            <div class="col-xs-12 col-md-10">
                                <fieldset class="component-group-list">
                                    <!-- All form components here for pushbullet client -->
                                    <config-toggle-slider :checked="notifiers.pushbullet.enabled" label="Enable" id="use_pushbullet" :explanations="['Send pushbullet notifications?']" @change="save()"  @update="notifiers.pushbullet.enabled = $event"></config-toggle-slider>
                                    <div v-show="notifiers.pushbullet.enabled" id="content-use-pushbullet-client"> <!-- show based on notifiers.pushbullet.enabled -->
    
                                        <config-toggle-slider :checked="notifiers.pushbullet.notifyOnSnatch" label="Notify on snatch" id="pushbullet_notify_onsnatch" :explanations="['send a notification when a download starts?']" @change="save()"  @update="notifiers.pushbullet.notifyOnSnatch = $event"></config-toggle-slider>
                                        <config-toggle-slider :checked="notifiers.pushbullet.notifyOnDownload" label="Notify on download" id="pushbullet_notify_ondownload" :explanations="['send a notification when a download finishes?']" @change="save()"  @update="notifiers.pushbullet.notifyOnDownload = $event"></config-toggle-slider>
                                        <config-toggle-slider :checked="notifiers.pushbullet.notifyOnSubtitleDownload" label="Notify on subtitle download" id="pushbullet_notify_onsubtitledownload" :explanations="['send a notification when subtitles are downloaded?']" @change="save()"  @update="notifiers.pushbullet.notifyOnSubtitleDownload = $event"></config-toggle-slider>
                                        <config-textbox :value="notifiers.pushbullet.api" label="Pushbullet API key" id="pushbullet_api" :explanations="['API key of your Pushbullet account.']" @change="save()"  @update="notifiers.pushbullet.api = $event"></config-textbox>

                                        <div class="form-group">
                                            <div class="row">
                                                <label for="pushover_spound" class="col-sm-2 control-label">
                                                    <span>Pushbullet devices</span>
                                                </label>
                                                <div class="col-sm-10 content">
                                                    <input type="button" class="btn-medusa btn-inline" value="Update device list" id="get-pushbullet-devices" @click="getPushbulletDeviceOptions" />
                                                    <select id="pushbullet_device_list" name="pushbullet_device_list" v-model="notifiers.pushbullet.device" class="form-control">
                                                        <option v-for="option in pushbulletDeviceOptions" v-bind:value="option.value" @change="pushbulletTestInfo = 'Don\'t forget to save your new pushbullet settings.'">
                                                            {{ option.text }}
                                                        </option>
                                                    </select>
                                                    <span>select device you wish to push to.</span>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="testNotification" id="testPushbullet-resultsfsf">{{pushbulletTestInfo}}</div>
                                        <input type="button" class="btn-medusa" value="Test Pushbullet" id="testPushbullet" @click="testPushbulletApi" />
                                        <input type="submit" class="btn-medusa config_submitter" value="Save Changes" />
                                    </div>
                                </fieldset>
                            </div>
                        </div>



                        <div class="component-group-desc-legacy">
                            <span class="icon-notifiers-freemobile" title="Free Mobile"></span>
                            <h3><app-link href="http://mobile.free.fr/">Free Mobile</app-link></h3>
                            <p>Free Mobile is a famous French cellular network provider.<br> It provides to their customer a free SMS API.</p>
                        </div>
                    <div class="component-group">
                        <fieldset class="component-group-list">
                            <div class="field-pair">
                                <label for="use_freemobile">
                                    <span class="component-title">Enable</span>
                                    <span class="component-desc">
                                        <input type="checkbox" class="enabler" name="use_freemobile" id="use_freemobile" ${'checked="checked"' if app.USE_FREEMOBILE else ''}/>
                                        <p>Send SMS notifications?</p>
                                    </span>
                                </label>
                            </div>
                            <div id="content_use_freemobile">
                                <div class="field-pair">
                                    <label for="freemobile_notify_onsnatch">
                                        <span class="component-title">Notify on snatch</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="freemobile_notify_onsnatch" id="freemobile_notify_onsnatch" ${'checked="checked"' if app.FREEMOBILE_NOTIFY_ONSNATCH else ''}/>
                                            <p>send a SMS when a download starts?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="freemobile_notify_ondownload">
                                        <span class="component-title">Notify on download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="freemobile_notify_ondownload" id="freemobile_notify_ondownload" ${'checked="checked"' if app.FREEMOBILE_NOTIFY_ONDOWNLOAD else ''}/>
                                            <p>send a SMS when a download finishes?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="freemobile_notify_onsubtitledownload">
                                        <span class="component-title">Notify on subtitle download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="freemobile_notify_onsubtitledownload" id="freemobile_notify_onsubtitledownload" ${'checked="checked"' if app.FREEMOBILE_NOTIFY_ONSUBTITLEDOWNLOAD else ''}/>
                                            <p>send a SMS when subtitles are downloaded?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="freemobile_id">
                                        <span class="component-title">Free Mobile customer ID</span>
                                        <input type="text" name="freemobile_id" id="freemobile_id" value="${app.FREEMOBILE_ID}" class="form-control input-sm input250"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">It's your Free Mobile customer ID (8 digits)</span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="freemobile_password">
                                        <span class="component-title">Free Mobile API Key</span>
                                        <input type="text" name="freemobile_apikey" id="freemobile_apikey" value="${app.FREEMOBILE_APIKEY}" class="form-control input-sm input250"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">Find your API Key in your customer portal.</span>
                                    </label>
                                </div>
                                <div class="testNotification" id="testFreeMobile-result">Click below to test your settings.</div>
                                <input  class="btn-medusa" type="button" value="Test SMS" id="testFreeMobile" />
                                <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                            </div><!-- /content_use_freemobile //-->
                        </fieldset>
                    </div><!-- /freemobile component-group //-->

                    <div class="component-group-desc-legacy">
                        <span class="icon-notifiers-telegram" title="Telegram"></span>
                        <h3><app-link href="https://telegram.org/">Telegram</app-link></h3>
                        <p>Telegram is a cloud-based instant messaging service.</p>
                    </div>
                    <div class="component-group">
                        <fieldset class="component-group-list">
                            <div class="field-pair">
                                <label for="use_telegram">
                                    <span class="component-title">Enable</span>
                                    <span class="component-desc">
                                        <input type="checkbox" class="enabler" name="use_telegram" id="use_telegram" ${'checked="checked"' if app.USE_TELEGRAM else ''}/>
                                        <p>Send Telegram notifications?</p>
                                    </span>
                                </label>
                            </div>
                            <div id="content_use_telegram">
                                <div class="field-pair">
                                    <label for="telegram_notify_onsnatch">
                                        <span class="component-title">Notify on snatch</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="telegram_notify_onsnatch" id="telegram_notify_onsnatch" ${'checked="checked"' if app.TELEGRAM_NOTIFY_ONSNATCH else ''}/>
                                            <p>Send a message when a download starts?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="telegram_notify_ondownload">
                                        <span class="component-title">Notify on download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="telegram_notify_ondownload" id="telegram_notify_ondownload" ${'checked="checked"' if app.TELEGRAM_NOTIFY_ONDOWNLOAD else ''}/>
                                            <p>Send a message when a download finishes?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="telegram_notify_onsubtitledownload">
                                        <span class="component-title">Notify on subtitle download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="telegram_notify_onsubtitledownload" id="telegram_notify_onsubtitledownload" ${'checked="checked"' if app.TELEGRAM_NOTIFY_ONSUBTITLEDOWNLOAD else ''}/>
                                            <p>Send a message when subtitles are downloaded?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="telegram_id">
                                        <span class="component-title">User/group ID</span>
                                        <input type="text" name="telegram_id" id="telegram_id" value="${app.TELEGRAM_ID}" class="form-control input-sm input250"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">Contact @myidbot on Telegram to get an ID</span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="telegram_password">
                                        <span class="component-title">Bot API token</span>
                                        <input type="text" name="telegram_apikey" id="telegram_apikey" value="${app.TELEGRAM_APIKEY}" class="form-control input-sm input250"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">Contact @BotFather on Telegram to set up one</span>
                                    </label>
                                </div>
                                <div class="testNotification" id="testTelegram-result">Click below to test your settings.</div>
                                <input  class="btn-medusa" type="button" value="Test Telegram" id="testTelegram" />
                                <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                            </div><!-- /content_use_telegram //-->
                        </fieldset>
                    </div><!-- /telegram component-group //-->
                </div><!-- #devices //-->
                <div id="social">
                    <div class="component-group-desc-legacy">
                        <span class="icon-notifiers-twitter" title="Twitter"></span>
                        <h3><app-link href="https://www.twitter.com">Twitter</app-link></h3>
                        <p>A social networking and microblogging service, enabling its users to send and read other users' messages called tweets.</p>
                    </div>
                    <div class="component-group">
                        <fieldset class="component-group-list">
                            <div class="field-pair">
                                <label for="use_twitter">
                                    <span class="component-title">Enable</span>
                                    <span class="component-desc">
                                        <input type="checkbox" class="enabler" name="use_twitter" id="use_twitter" ${'checked="checked"' if app.USE_TWITTER else ''}/>
                                        <p>Should Medusa post tweets on Twitter?</p>
                                    </span>
                                </label>
                                <label>
                                    <span class="component-title">&nbsp;</span>
                                    <span class="component-desc"><b>Note:</b> you may want to use a secondary account.</span>
                                </label>
                            </div>
                            <div id="content_use_twitter">
                                <div class="field-pair">
                                    <label for="twitter_notify_onsnatch">
                                        <span class="component-title">Notify on snatch</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="twitter_notify_onsnatch" id="twitter_notify_onsnatch" ${'checked="checked"' if app.TWITTER_NOTIFY_ONSNATCH else ''}/>
                                            <p>send a notification when a download starts?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="twitter_notify_ondownload">
                                        <span class="component-title">Notify on download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="twitter_notify_ondownload" id="twitter_notify_ondownload" ${'checked="checked"' if app.TWITTER_NOTIFY_ONDOWNLOAD else ''}/>
                                            <p>send a notification when a download finishes?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="twitter_notify_onsubtitledownload">
                                        <span class="component-title">Notify on subtitle download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="twitter_notify_onsubtitledownload" id="twitter_notify_onsubtitledownload" ${'checked="checked"' if app.TWITTER_NOTIFY_ONSUBTITLEDOWNLOAD else ''}/>
                                            <p>send a notification when subtitles are downloaded?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="twitter_usedm">
                                        <span class="component-title">Send direct message</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="twitter_usedm" id="twitter_usedm" ${'checked="checked"' if app.TWITTER_USEDM else ''}/>
                                            <p>send a notification via Direct Message, not via status update</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="twitter_dmto">
                                        <span class="component-title">Send DM to</span>
                                        <input type="text" name="twitter_dmto" id="twitter_dmto" value="${app.TWITTER_DMTO}" class="form-control input-sm input250"/>
                                    </label>
                                    <p>
                                        <span class="component-desc">Twitter account to send Direct Messages to (must follow you)</span>
                                    </p>
                                </div>
                                <div class="field-pair">
                                    <label>
                                        <span class="component-title">Step One</span>
                                    </label>
                                    <label>
                                        <span style="font-size: 11px;">Click the "Request Authorization" button.<br> This will open a new page containing an auth key.<br> <b>Note:</b> if nothing happens check your popup blocker.<br></span>
                                        <input class="btn-medusa" type="button" value="Request Authorization" id="twitterStep1" />
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label>
                                        <span class="component-title">Step Two</span>
                                    </label>
                                    <label>
                                        <span style="font-size: 11px;">Enter the key Twitter gave you below, and click "Verify Key".<br><br></span>
                                        <input type="text" id="twitter_key" value="" class="form-control input-sm input350"/>
                                        <input class="btn-medusa btn-inline" type="button" value="Verify Key" id="twitterStep2" />
                                    </label>
                                </div>
                                <!--
                                <div class="field-pair">
                                    <label>
                                        <span class="component-title">Step Three</span>
                                    </label>
                                </div>
                                //-->
                                <div class="testNotification" id="testTwitter-result">Click below to test.</div>
                                <input  class="btn-medusa" type="button" value="Test Twitter" id="testTwitter" />
                                <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                            </div><!-- /content_use_twitter //-->
                        </fieldset>
                    </div><!-- twitter .component-group //-->
                        <div class="component-group-desc-legacy">
                            <span class="icon-notifiers-trakt" title="Trakt"></span>
                            <h3><app-link href="https://trakt.tv/">Trakt</app-link></h3>
                            <p>trakt helps keep a record of what TV shows and movies you are watching. Based on your favorites, trakt recommends additional shows and movies you'll enjoy!</p>
                        </div><!-- .component-group-desc-legacy //-->
                    <div class="component-group">
                        <fieldset class="component-group-list">
                            <div class="field-pair">
                                <label for="use_trakt">
                                    <span class="component-title">Enable</span>
                                    <span class="component-desc">
                                        <input type="checkbox" class="enabler" name="use_trakt" id="use_trakt" ${'checked="checked"' if app.USE_TRAKT else ''}/>
                                        <p>Send Trakt.tv notifications?</p>
                                    </span>
                                </label>
                            </div><!-- .field-pair //-->
                            <div id="content_use_trakt">
                                <div class="field-pair">
                                    <label for="trakt_username">
                                        <span class="component-title">Username</span>
                                        <input type="text" name="trakt_username" id="trakt_username" value="${app.TRAKT_USERNAME}" class="form-control input-sm input250"
                                               autocomplete="no" />
                                    </label>
                                    <p>
                                        <span class="component-desc">username of your Trakt account.</span>
                                    </p>
                                </div>
                                <input type="hidden" id="trakt_pin_url" value="${app.TRAKT_PIN_URL}">
                                <div class="field-pair">
                                    <label for="trakt_pin">
                                        <span class="component-title">Trakt PIN</span>
                                        <input type="text" name="trakt_pin" id="trakt_pin" value="" class="form-control input-sm input250" ${'disabled' if app.TRAKT_ACCESS_TOKEN else ''} />
                                        <input type="button" class="btn-medusa" value="Get ${'New' if app.TRAKT_ACCESS_TOKEN else ''} Trakt PIN" id="TraktGetPin" />
                                        <input type="button" class="btn-medusa hide" value="Authorize Medusa" id="authTrakt" />
                                    </label>
                                    <p>
                                        <span class="component-desc">PIN code to authorize Medusa to access Trakt on your behalf.</span>
                                    </p>
                                </div>
                                <div class="field-pair">
                                    <label for="trakt_timeout">
                                        <span class="component-title">API Timeout</span>
                                        <input type="number" min="10" step="1" name="trakt_timeout" id="trakt_timeout" value="${app.TRAKT_TIMEOUT}" class="form-control input-sm input75"/>
                                    </label>
                                    <p>
                                        <span class="component-desc">
                                            Seconds to wait for Trakt API to respond. (Use 0 to wait forever)
                                        </span>
                                    </p>
                                </div>
                                <div class="field-pair">
                                    <label for="trakt_default_indexer">
                                        <span class="component-title">Default indexer</span>
                                        <span class="component-desc">
                                            <select id="trakt_default_indexer" name="trakt_default_indexer" class="form-control input-sm">
                                                <% indexers = indexerApi().indexers %>
                                                % for indexer in indexers:
                                                    <%
                                                        if not get_trakt_indexer(indexer):
                                                            continue
                                                    %>
                                                <option value="${indexer}" ${'selected="selected"' if app.TRAKT_DEFAULT_INDEXER == indexer else ''}>${indexers[indexer]}</option>
                                                % endfor
                                            </select>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="trakt_sync">
                                        <span class="component-title">Sync libraries</span>
                                        <span class="component-desc">
                                            <input type="checkbox" class="enabler" name="trakt_sync" id="trakt_sync" ${'checked="checked"' if app.TRAKT_SYNC else ''}/>
                                            <p>Sync your Medusa show library with your Trakt collection.</p>
                                            <p><b>Note:</b> Don't enable this setting if you use the Trakt addon for Kodi or any other script that syncs your library.</p>
                                            <p>Kodi detects that the episode was deleted and removes from collection which causes Medusa to re-add it. This causes a loop between Medusa and Kodi adding and deleting the episode.</p>
                                        </span>
                                    </label>
                                </div>
                                <div id="content_trakt_sync">
                                    <div class="field-pair">
                                        <label for="trakt_sync_remove">
                                            <span class="component-title">Remove Episodes From Collection</span>
                                            <span class="component-desc">
                                                <input type="checkbox" name="trakt_sync_remove" id="trakt_sync_remove" ${'checked="checked"' if app.TRAKT_SYNC_REMOVE else ''}/>
                                                <p>Remove an Episode from your Trakt Collection if it is not in your Medusa Library.</p>
                                                <p><b>Note:</b> Don't enable this setting if you use the Trakt addon for Kodi or any other script that syncs your library.</p>
                                            </span>
                                        </label>
                                     </div>
                                </div>
                                <div class="field-pair">
                                    <label for="trakt_sync_watchlist">
                                        <span class="component-title">Sync watchlist</span>
                                        <span class="component-desc">
                                            <input type="checkbox" class="enabler" name="trakt_sync_watchlist" id="trakt_sync_watchlist" ${'checked="checked"' if app.TRAKT_SYNC_WATCHLIST else ''}/>
                                            <p>Sync your Medusa library with your Trakt Watchlist (either Show and Episode).</p>
                                            <p>Episode will be added on watch list when wanted or snatched and will be removed when downloaded </p>
                                            <p><b>Note:</b> By design, Trakt automatically removes episodes and/or shows from watchlist as soon you have watched them.</p>
                                        </span>
                                    </label>
                                </div>
                                <div id="content_trakt_sync_watchlist">
                                    <div class="field-pair">
                                        <label for="trakt_method_add">
                                            <span class="component-title">Watchlist add method</span>
                                               <select id="trakt_method_add" name="trakt_method_add" class="form-control input-sm">
                                                <option value="0" ${'selected="selected"' if app.TRAKT_METHOD_ADD == 0 else ''}>Skip All</option>
                                                <option value="1" ${'selected="selected"' if app.TRAKT_METHOD_ADD == 1 else ''}>Download Pilot Only</option>
                                                <option value="2" ${'selected="selected"' if app.TRAKT_METHOD_ADD == 2 else ''}>Get whole show</option>
                                            </select>
                                        </label>
                                        <label>
                                            <span class="component-title">&nbsp;</span>
                                            <span class="component-desc">method in which to download episodes for new shows.</span>
                                        </label>
                                    </div>
                                    <div class="field-pair">
                                        <label for="trakt_remove_watchlist">
                                            <span class="component-title">Remove episode</span>
                                            <span class="component-desc">
                                                <input type="checkbox" name="trakt_remove_watchlist" id="trakt_remove_watchlist" ${'checked="checked"' if app.TRAKT_REMOVE_WATCHLIST else ''}/>
                                                <p>remove an episode from your watchlist after it is downloaded.</p>
                                            </span>
                                        </label>
                                    </div>
                                    <div class="field-pair">
                                        <label for="trakt_remove_serieslist">
                                            <span class="component-title">Remove series</span>
                                            <span class="component-desc">
                                                <input type="checkbox" name="trakt_remove_serieslist" id="trakt_remove_serieslist" ${'checked="checked"' if app.TRAKT_REMOVE_SERIESLIST else ''}/>
                                                <p>remove the whole series from your watchlist after any download.</p>
                                            </span>
                                        </label>
                                    </div>
                                    <div class="field-pair">
                                        <label for="trakt_remove_show_from_application">
                                            <span class="component-title">Remove watched show:</span>
                                            <span class="component-desc">
                                                <input type="checkbox" name="trakt_remove_show_from_application" id="trakt_remove_show_from_application" ${'checked="checked"' if app.TRAKT_REMOVE_SHOW_FROM_APPLICATION else ''}/>
                                                <p>remove the show from Medusa if it's ended and completely watched</p>
                                            </span>
                                        </label>
                                    </div>
                                    <div class="field-pair">
                                        <label for="trakt_start_paused">
                                            <span class="component-title">Start paused</span>
                                            <span class="component-desc">
                                                <input type="checkbox" name="trakt_start_paused" id="trakt_start_paused" ${'checked="checked"' if app.TRAKT_START_PAUSED else ''}/>
                                                <p>shows grabbed from your trakt watchlist start paused.</p>
                                            </span>
                                        </label>
                                    </div>
                                </div>
                                <div class="field-pair">
                                    <label for="trakt_blacklist_name">
                                        <span class="component-title">Trakt blackList name</span>
                                        <input type="text" name="trakt_blacklist_name" id="trakt_blacklist_name" value="${app.TRAKT_BLACKLIST_NAME}" class="form-control input-sm input150"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">Name(slug) of List on Trakt for blacklisting show on 'Add Trending Show' & 'Add Recommended Shows' pages</span>
                                    </label>
                                </div>
                                <div class="testNotification" id="testTrakt-result">Click below to test.</div>
                                <input type="button" class="btn-medusa" value="Test Trakt" id="testTrakt" />
                                <input type="button" class="btn-medusa" value="Force Sync" id="forceSync" />
                                <input type="submit" class="btn-medusa config_submitter" value="Save Changes" />
                            </div><!-- #content_use_trakt //-->
                        </fieldset><!-- .component-group-desc-legacy //-->
                    </div><!-- trakt .component-group //-->

                    <div class="component-group-desc-legacy">
                        <span class="icon-notifiers-email" title="Email"></span>
                        <h3><app-link href="https://en.wikipedia.org/wiki/Comparison_of_webmail_providers">Email</app-link></h3>
                        <p>Allows configuration of email notifications on a per show basis.</p>
                    </div><!-- .component-group-desc-legacy //-->
                    <div class="component-group">
                        <fieldset class="component-group-list">
                            <div class="field-pair">
                                <label for="use_email">
                                    <span class="component-title">Enable</span>
                                    <span class="component-desc">
                                        <input type="checkbox" class="enabler" name="use_email" id="use_email" ${'checked="checked"' if app.USE_EMAIL else ''}/>
                                        <p>Send email notifications?</p>
                                    </span>
                                </label>
                            </div><!-- .field-pair //-->
                            <div id="content_use_email">
                                <div class="field-pair">
                                    <label for="email_notify_onsnatch">
                                        <span class="component-title">Notify on snatch</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="email_notify_onsnatch" id="email_notify_onsnatch" ${'checked="checked"' if app.EMAIL_NOTIFY_ONSNATCH else ''}/>
                                            <p>send a notification when a download starts?</p>
                                        </span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_notify_ondownload">
                                        <span class="component-title">Notify on download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="email_notify_ondownload" id="email_notify_ondownload" ${'checked="checked"' if app.EMAIL_NOTIFY_ONDOWNLOAD else ''}/>
                                            <p>send a notification when a download finishes?</p>
                                        </span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_notify_onsubtitledownload">
                                        <span class="component-title">Notify on subtitle download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="email_notify_onsubtitledownload" id="email_notify_onsubtitledownload" ${'checked="checked"' if app.EMAIL_NOTIFY_ONSUBTITLEDOWNLOAD else ''}/>
                                            <p>send a notification when subtitles are downloaded?</p>
                                        </span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_host">
                                        <span class="component-title">SMTP host</span>
                                        <input type="text" name="email_host" id="email_host" value="${app.EMAIL_HOST}" class="form-control input-sm input250"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">hostname of your SMTP email server.</span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_port">
                                        <span class="component-title">SMTP port</span>
                                        <input type="number" min="1" step="1" name="email_port" id="email_port" value="${app.EMAIL_PORT}" class="form-control input-sm input75"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">port number used to connect to your SMTP host.</span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_from">
                                        <span class="component-title">SMTP from</span>
                                        <input type="text" name="email_from" id="email_from" value="${app.EMAIL_FROM}" class="form-control input-sm input250"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">sender email address, some hosts require a real address.</span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_tls">
                                        <span class="component-title">Use TLS</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="email_tls" id="email_tls" ${'checked="checked"' if app.EMAIL_TLS else ''}/>
                                            <p>check to use TLS encryption.</p>
                                        </span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_user">
                                        <span class="component-title">SMTP user</span>
                                        <input type="text" name="email_user" id="email_user" value="${app.EMAIL_USER}" class="form-control input-sm input250"
                                               autocomplete="no" />
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">(optional) your SMTP server username.</span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_password">
                                        <span class="component-title">SMTP password</span>
                                        <input type="password" name="email_password" id="email_password" value="${app.EMAIL_PASSWORD}" class="form-control input-sm input250" autocomplete="no"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">(optional) your SMTP server password.</span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_list">
                                        <span class="component-title">Global email list</span>
                                        <input type="text" name="email_list" id="email_list" value="${','.join(app.EMAIL_LIST)}" class="form-control input-sm input350"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">
                                            Email addresses listed here, separated by commas if applicable, will<br>
                                            receive notifications for <b>all</b> shows.<br>
                                            (This field may be blank except when testing.)
                                        </span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_subject">
                                        <span class="component-title">Email Subject</span>
                                        <input type="text" name="email_subject" id="email_subject" value="${app.EMAIL_SUBJECT}" class="form-control input-sm input350"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">
                                            Use a custom subject for some privacy protection?<br>
                                            (Leave blank for the default Medusa subject)
                                        </span>
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="field-pair">
                                    <label for="email_show">
                                        <span class="component-title">Show notification list</span>
                                        <select name="email_show" id="email_show" class="form-control input-sm">
                                            <option value="-1">-- Select a Show --</option>
                                        </select>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <input type="text" name="email_show_list" id="email_show_list" class="form-control input-sm input350"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">
                                            Configure per-show notifications here by entering email address(es), separated by commas,
                                            after selecting a show in the drop-down box.   Be sure to activate the 'Save for this show'
                                            button below after each entry.
                                        </span>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <input id="email_show_save" class="btn-medusa" type="button" value="Save for this show" />
                                    </label>
                                </div><!-- .field-pair //-->
                                <div class="testNotification" id="testEmail-result">
                                    Click below to test.
                                </div><!-- #testEmail-result //-->
                                <input class="btn-medusa" type="button" value="Test Email" id="testEmail" />
                                <input class="btn-medusa" type="submit" class="config_submitter" value="Save Changes" />
                            </div><!-- #content_use_email //-->
                        </fieldset><!-- .component-group-list //-->
                    </div><!-- email .component-group //-->


                    <div class="component-group-desc-legacy">
                        <span class="icon-notifiers-slack" title="Slack"></span>
                        <h3><app-link href="https://slack.com">Slack</app-link></h3>
                        <p>Slack is a messaging app for teams.</p>
                    </div>
                    <div class="component-group">
                        <fieldset class="component-group-list">
                            <div class="field-pair">
                                <label for="use_slack">
                                    <span class="component-title">Enable</span>
                                    <span class="component-desc">
                                        <input type="checkbox" class="enabler" name="use_slack" id="use_slack" ${'checked="checked"' if app.USE_SLACK else ''}/>
                                        <p>Send Slack notifications?</p>
                                    </span>
                                </label>
                            </div>
                            <div id="content_use_slack">
                                <div class="field-pair">
                                    <label for="slack_notify_onsnatch">
                                        <span class="component-title">Notify on snatch</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="slack_notify_onsnatch" id="slack_notify_onsnatch" ${'checked="checked"' if app.SLACK_NOTIFY_SNATCH else ''}/>
                                            <p>Send a message when a download starts?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="slack_notify_ondownload">
                                        <span class="component-title">Notify on download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="slack_notify_ondownload" id="slack_notify_ondownload" ${'checked="checked"' if app.SLACK_NOTIFY_DOWNLOAD else ''}/>
                                            <p>Send a message when a download finishes?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="slack_notify_onsubtitledownload">
                                        <span class="component-title">Notify on subtitle download</span>
                                        <span class="component-desc">
                                            <input type="checkbox" name="slack_notify_onsubtitledownload" id="slack_notify_onsubtitledownload" ${'checked="checked"' if app.SLACK_NOTIFY_SUBTITLEDOWNLOAD else ''}/>
                                            <p>Send a message when subtitles are downloaded?</p>
                                        </span>
                                    </label>
                                </div>
                                <div class="field-pair">
                                    <label for="slack_webhook">
                                        <span class="component-title">Slack Incoming Webhook</span>
                                        <input type="text" name="slack_webhook" id="slack_webhook" value="${app.SLACK_WEBHOOK}" class="form-control input-sm input250"/>
                                    </label>
                                    <label>
                                        <span class="component-title">&nbsp;</span>
                                        <span class="component-desc">Create an incoming webhook, to communicate with your slack channel.
                                        <app-link href="https://my.slack.com/services/new/incoming-webhook">https://my.slack.com/services/new/incoming-webhook/</app-link></span>
                                    </label>
                                </div>
                                <div class="testNotification" id="testSlack-result">Click below to test your settings.</div>
                                <input  class="btn-medusa" type="button" value="Test Slack" id="testSlack" />
                                <input type="submit" class="config_submitter btn-medusa" value="Save Changes" />
                            </div><!-- /content_use_slack //-->
                        </fieldset>
                    </div><!-- /slack component-group //-->

                </div><!-- #social //-->
                <br><input type="submit" class="config_submitter btn-medusa" value="Save Changes" /><br>
            </div><!-- #config-components //-->
        </form><!-- #configForm //-->
    </div><!-- #config-content //-->
</div><!-- #config //-->
<div class="clearfix"></div>
</%block>
