Rails.application.routes.draw do
  resources 'flights', only: [:show, :index], param: :name do
    get :purchase, on: :member
    post :transaction, on: :member
    get :list_transactions, on: :collection
  end
  root :to => "flights#index"
end
