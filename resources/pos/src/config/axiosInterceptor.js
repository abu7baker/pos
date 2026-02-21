import {Tokens, errorMessage} from '../constants';
import {environment} from './environment'

export default {
    setupInterceptors: (axios, isToken = false, isFormData = false) => {
        axios.interceptors.request.use((config) => {
                if (isToken) {
                    return config;
                }
                let isToken = localStorage.getItem(Tokens.ADMIN);
                if (isToken) {
                    config.headers['Authorization'] = `Bearer ${isToken}`;
                }
                if (!isToken) {
                    if (!window.location.href.includes('login') && !window.location.href.includes('reset-password') && !window.location.href.includes('forgot-password')) {
                        window.location.href = environment.URL + '#/' + 'login';
                    }
                }
                if (isFormData) {
                    config.headers['Content-Type'] = 'multipart/form-data';
                }
                return config;
            },
            (error) => {
                return Promise.reject(error);
            }
        );
        axios.interceptors.response.use(
            response => successHandler(response),
            error => errorHandler(error)
        );
        const errorHandler = (error) => {
            if (!error.response) {
                return Promise.reject({...error});
            }
            const {status, data} = error.response;
            if (status === 401
                || data.message === errorMessage.TOKEN_NOT_PROVIDED
                || data.message === errorMessage.TOKEN_INVALID
                || data.message === errorMessage.TOKEN_INVALID_SIGNATURE
                || data.message === errorMessage.TOKEN_EXPIRED) {
                localStorage.removeItem(Tokens.ADMIN);
                localStorage.removeItem(Tokens.USER);
                localStorage.removeItem(Tokens.GET_PERMISSIONS);
                window.location.href = environment.URL + '#' + '/login';
            } else if (status === 403 || status === 404) {
                window.location.href = environment.URL + '#' + '/app/dashboard';
            } else {
                return Promise.reject({...error})
            }
        };
        const successHandler = (response) => {
            return response;
        };
    }
};
